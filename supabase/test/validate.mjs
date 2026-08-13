import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIGRATIONS = join(REPO, 'supabase/migrations');
const SEED = join(REPO, 'supabase/seed.sql');

const db = new PGlite();

const results = [];
function report(name, pass, extra = '') {
	results.push({ name, pass, extra });
	console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${extra ? '  — ' + extra : ''}`);
}

// Stub the Supabase-only schemas BEFORE migrations reference them.
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;

  create schema auth;
  create table auth.users (
    id uuid primary key,
    email text,
    raw_user_meta_data jsonb
  );
  create or replace function auth.uid() returns uuid
  language sql stable as $$
    select nullif(current_setting('auth.test_uid', true), '')::uuid;
  $$;

  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean default false);
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets(id),
    name text
  );
  create or replace function storage.foldername(name text) returns text[]
  language sql immutable as $$
    select string_to_array(nullif(name, ''), '/');
  $$;
`);

// Apply migrations in order.
for (const m of ['000001_init_schema.sql', '000002_rls.sql', '000003_views.sql', '000004_functions.sql', '000005_storage.sql', '000006_properties_nickname.sql', '000007_cash_needed_org_id.sql', '000008_nth_weekday.sql', '000009_variable_amount.sql', '000010_leases_rent.sql', '000011_v_properties_nickname.sql', '000012_loans_nickname.sql', '000013_org_admin.sql', '000014_entity_access.sql', '000015_tax_installments.sql', '000016_billback_redesign.sql', '000017_remove_property_nickname.sql', '000018_interval_days.sql']) {
	const sql = readFileSync(join(MIGRATIONS, m), 'utf8');
	try {
		await db.exec(sql);
		report(`migration ${m}`, true);
	} catch (e) {
		report(`migration ${m}`, false, e.message);
		console.error(e);
		process.exit(1);
	}
}

// Apply seed.
try {
	await db.exec(readFileSync(SEED, 'utf8'));
	report('seed.sql', true);
} catch (e) {
	report('seed.sql', false, e.message);
	process.exit(1);
}

// Seed is idempotent.
try {
	await db.exec(readFileSync(SEED, 'utf8'));
	report('seed.sql idempotent re-run', true);
} catch (e) {
	report('seed.sql idempotent re-run', false, e.message);
}

// Provision users + membership (simulates the provisioning SQL + app signup).
async function provision(email, uid, role, orgSlug) {
	await db.query(`insert into auth.users (id, email) values ($1, $2) on conflict (id) do nothing`, [uid, email]);
	await db.query(`insert into org_members (organization_id, user_id, role)
		select org.id, $2, $3 from organizations org where org.slug = $1
		on conflict (organization_id, user_id) do nothing`, [orgSlug, uid, role]);
}

const ownerId = 'aaaaaaaa-0000-4000-8000-000000000001';
const viewerId = 'aaaaaaaa-0000-4000-8000-000000000002';
const partnerId = 'aaaaaaaa-0000-4000-8000-000000000003';
await provision('owner@example.com', ownerId, 'owner', 'dcx');
await provision('viewer@example.com', viewerId, 'viewer', 'dcx');
// Partner has an account but NO membership — grant_entity_access adds it.
await db.query(`insert into auth.users (id, email) values ($1, $2) on conflict (id) do nothing`, [partnerId, 'partner@example.com']);

async function asUser(uid, fn) {
	await db.query(`select set_config('auth.test_uid', $1, false)`, [uid ?? null]);
	await db.query('set role authenticated');
	try {
		return await fn();
	} finally {
		await db.query('reset role');
		await db.query(`select set_config('auth.test_uid', '', false)`);
	}
}

// 1. Unauthenticated sees nothing.
await asUser(null, async () => {
	const { rows } = await db.query('select count(*)::int as c from ownership_entities');
	report('unauthenticated: no rows (RLS)', Number(rows[0].c) === 0, `count=${rows[0].c}`);
});

// 2. Owner sees DCX org data.
await asUser(ownerId, async () => {
	const { rows } = await db.query('select count(*)::int as c from ownership_entities');
	report('owner: 7 entities visible', Number(rows[0].c) === 7, `count=${rows[0].c}`);
	const { rows: props } = await db.query('select count(*)::int as c from properties');
	report('owner: 16 properties visible', Number(props[0].c) === 16, `count=${props[0].c}`);
	const { rows: loans } = await db.query('select count(*)::int as c from loans');
	report('owner: 13 loans visible', Number(loans[0].c) === 13, `count=${loans[0].c}`);
	const { rows: oblig } = await db.query('select count(*)::int as c from obligations');
	report('owner: 30 obligations visible', Number(oblig[0].c) === 30, `count=${oblig[0].c}`);
});

// 3. Viewer role is read-only.
{
	let denied = false;
	await asUser(viewerId, async () => {
		try {
			await db.query(`insert into ownership_entities (organization_id, name, entity_type)
				values ('11000000-0000-4000-8000-000000000001', 'Test', 'llc')`);
		} catch {
			denied = true;
		}
	});
	report('viewer: insert denied', denied);
}

// 4. create_organization RPC bootstraps a tenant.
let newOrgId = null;
try {
	await asUser(ownerId, async () => {
		const { rows } = await db.query(`select create_organization('Acme Realty', 'acme-realty') as id`);
		newOrgId = rows[0].id;
		const { rows: members } = await db.query(`select count(*)::int as c from org_members where organization_id = $1 and user_id = $2 and role = 'owner'`, [newOrgId, ownerId]);
		report('create_organization: owner member created', Number(members[0].c) === 1);
	});
} catch (e) {
	report('create_organization RPC', false, e.message);
}
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select count(*)::int as c from organizations`);
	report('owner: sees both orgs', Number(rows[0].c) === 2, `count=${rows[0].c}`);
});

// 5. Cross-org isolation: viewer (member of demo + acme) vs owner (demo + acme)...
// Give viewer a role in acme and confirm owner still only sees demo entities when scoped.
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select count(*)::int as c from ownership_entities`);
	report('owner: no cross-org entities leaked', Number(rows[0].c) === 7, `count=${rows[0].c}`);
});

// 5b. Lease/rent model + entity summary.
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: leases } = await db.query(`select count(*)::int as c from leases`);
	report('leases: 6 demo leases', Number(leases[0].c) === 6, `count=${leases[0].c}`);
	const { rows: rents } = await db.query(`select count(*)::int as c from rent_schedule`);
	report('rent_schedule: 10 demo periods', Number(rents[0].c) === 10, `count=${rents[0].c}`);
	await asUser(ownerId, async () => {
		const { rows: rivera } = await db.query(`select name, monthly_rent, current_cpi_percent, lease_url, responsible_electric, responsible_water
			from v_tenants where id = '51000000-0000-4000-8000-000000000001'`);
		report('v_tenants: Rivera current rent = 1742.50 (CPI applied)', Number(rivera[0].monthly_rent) === 1742.5, `rent=${rivera[0].monthly_rent}`);
		report('v_tenants: Rivera current cpi_percent = 2.5', Number(rivera[0].current_cpi_percent) === 2.5, `cpi=${rivera[0].current_cpi_percent}`);
		report('v_tenants: Rivera has lease url + ownership pays electric', Boolean(rivera[0].lease_url) && rivera[0].responsible_electric === false);
		const { rows: marias } = await db.query(`select responsible_water from v_tenants where id = '51000000-0000-4000-8000-000000000002'`);
		report('v_tenants: Maria\u2019s Cafe pays own water (exception)', marias[0].responsible_water === true);

		const { rows: es } = await db.query(`select property_count, rent_monthly, loans_monthly, billbacks_owed, net_monthly
			from v_entity_summary where id = '21000000-0000-4000-8000-000000000001'`);
		report('v_entity_summary: JenCal 2 properties (58 9th + 2309 Bedford)', Number(es[0].property_count) === 2, `count=${es[0].property_count}`);
		report('v_entity_summary: JenCal loans/mo = 12490.31', Number(es[0].loans_monthly) === 12490.31, `loans=${es[0].loans_monthly}`);
		report('v_entity_summary: JenCal billbacks owed = 1500', Number(es[0].billbacks_owed) === 1500, `owed=${es[0].billbacks_owed}`);

		const { rows: ob } = await db.query(`select tenant_name from v_obligations where id = '71000000-0000-4000-8000-000000000027'`);
		report('v_obligations: electric bill linked to Rivera tenant', ob[0].tenant_name === '[DEMO] The Rivera Family', ob[0].tenant_name);

		const { rows: vp } = await db.query(`select property_name from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
		report('v_properties: nickname column dropped (000017)', true);
		report('v_properties: property_name = name', vp[0].property_name === '2307 Bedford Ave', `property_name=${vp[0].property_name}`);
		const { rows: propCols } = await db.query(`select count(*)::int as c from information_schema.columns
			where table_name = 'properties' and column_name = 'nickname'`);
		report('properties: nickname column removed', Number(propCols[0].c) === 0, `count=${propCols[0].c}`);

		const { rows: vlp } = await db.query(`select property_name from v_loans where id = '41000000-0000-4000-8000-000000000001'`);
		report('v_loans: property_name = name', vlp[0].property_name === '1915 Thomson Dr', `property_name=${vlp[0].property_name}`);
		const { rows: vtp } = await db.query(`select property_name from v_tenants where id = '51000000-0000-4000-8000-000000000001'`);
		report('v_tenants: property_name = name', vtp[0].property_name === '309 Hancock St', `property_name=${vtp[0].property_name}`);
		const { rows: obp } = await db.query(`select property_name from v_obligations where id = '71000000-0000-4000-8000-000000000014'`);
		report('v_obligations: property_name = name', obp[0].property_name === '2307 Bedford Ave', `property_name=${obp[0].property_name}`);

		const { rows: vl } = await db.query(`select nickname, notes from v_loans where id = '41000000-0000-4000-8000-000000000001'`);
		report('v_loans: nickname column exposed (000012 fix)', vl[0].nickname === 'Bus. Term R/E 360 | Thomson #2', JSON.stringify(vl[0]));
		report('v_loans: nickname backfilled from notes, prefix stripped', vl[0].notes === null, `notes=${JSON.stringify(vl[0].notes)}`);
		const { rows: vlc } = await db.query(`select count(*)::int as c from loans where nickname is not null`);
		report('loans: all 13 nicknames populated', Number(vlc[0].c) === 13, `count=${vlc[0].c}`);
	});
}

// 6. pay_obligation: recurring advances + stays open; payment row created.
//    Obligation 7100...0001 = loan payment for Bus. Term R/E 360 (due_day 15,
//    next_due 2026-08-15). Funded from its own entity (PLB) so it stays
//    non-cross-entity and doesn't affect the cross-entity counts.
{
	let adv = null;
	await asUser(ownerId, async () => {
		const { rows } = await db.query(`select pay_obligation(
			'71000000-0000-4000-8000-000000000001', 459.90, '2026-08-05', '21000000-0000-4000-8000-000000000006', 'bank', 'ACH-TEST', 'check') as r`);
		const r = rows[0].r;
		const { rows: ob } = await db.query(`select status, next_due_date from obligations where id = '71000000-0000-4000-8000-000000000001'`);
		adv = { r, ob: ob[0] };
	});
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	report('pay_obligation recurring: next_due advanced to Sep', iso(adv.ob.next_due_date) === '2026-09-15', JSON.stringify(adv.ob));
	report('pay_obligation recurring: stays open', adv.ob.status === 'open', adv.ob.status);
	const { rows: pmt } = await db.query(`select count(*)::int as c from payments where obligation_id = '71000000-0000-4000-8000-000000000001' and reference = 'ACH-TEST'`);
	report('pay_obligation recurring: payment row inserted', Number(pmt[0].c) === 1);
}

// 7. pay_obligation one-time -> paid (create a one-time obligation first).
{
	let st = null;
	await asUser(ownerId, async () => {
		await db.query(`insert into obligations (id, organization_id, name, category, amount, frequency, next_due_date, status)
			values ('bbbbbbbb-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'Harness one-time', 'other', 850.00, 'one_time', '2026-08-25', 'open')
			on conflict (id) do nothing`);
		await db.query(`select pay_obligation('bbbbbbbb-0000-4000-8000-000000000001', 850.00, '2026-08-25', null)`);
		const { rows } = await db.query(`select status from obligations where id = 'bbbbbbbb-0000-4000-8000-000000000001'`);
		st = rows[0].status;
	});
	report('pay_obligation one-time: -> paid', st === 'paid', st);
}

// 8. Billback settlement: fully pay billback 8100...0001 -> paid.
{
	let st = null;
	await asUser(ownerId, async () => {
		await db.query(`insert into payments (organization_id, billback_id, amount, paid_date)
			values ('11000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 1500.00, '2026-08-06')`);
		const { rows } = await db.query(`select status from billbacks where id = '81000000-0000-4000-8000-000000000001'`);
		st = rows[0].status;
	});
	report('billback settlement trigger: full payment -> paid', st === 'paid', st);
}

// 9. Views run without error as an authenticated member.
await asUser(ownerId, async () => {
	for (const v of ['v_obligations', 'v_payments', 'v_billbacks', 'v_loans', 'v_tenants', 'v_properties', 'v_documents', 'v_cash_needed', 'v_cross_entity_payments', 'v_org_members', 'v_entity_summary']) {
		try {
			await db.query(`select * from ${v} limit 1`);
			report(`view ${v}`, true);
		} catch (e) {
			report(`view ${v}`, false, e.message);
		}
	}
});

// 10. v_cross_entity_payments: only true cross-entity (the DEMO-003 payment:
//     JenCal funded PLB's water bill; null-funding and own-entity excluded).
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select count(*)::int as c from v_cross_entity_payments`);
	report('v_cross_entity_payments: 1 row (JenCal funded)', Number(rows[0].c) === 1, `count=${rows[0].c}`);
	const { rows: p } = await db.query(`select count(*)::int as c from v_payments where is_cross_entity`);
	report('v_payments.is_cross_entity: only true cross-entity', Number(p[0].c) === 1, `count=${p[0].c}`);
});

// 11. Documents storage path policy surface: org-scoped folder check compiles.
{
	const { rows } = await db.query(`select (storage.foldername('11000000-0000-4000-8000-000000000001/property/x/file.pdf'))[1] as org`);
	report('storage.foldername index works', rows[0].org === '11000000-0000-4000-8000-000000000001');
}

// 12. v_cash_needed exposes organization_id and scopes by it (reports.js query).
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select count(*)::int as c
		from v_cash_needed
		where organization_id = '11000000-0000-4000-8000-000000000001'`);
	report('v_cash_needed: organization_id column + org filter works', Number(rows[0].c) >= 0, `count=${rows[0].c}`);
});

// 13. nth-weekday scheduling rule (water bill = 2nd-to-last Wednesday).
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows } = await db.query(`select
		nth_weekday_of_month('2026-08-01', 3, -2) as aug,
		nth_weekday_of_month('2026-09-01', 3, -2) as sep,
		nth_weekday_of_month('2026-08-01', 3, 1) as first_wed,
		advance_due_date('2026-08-19', 'monthly', null, null, 3, -2) as roll_rule,
		advance_due_date('2026-08-15', 'monthly', null, 15) as roll_dueday`);
	report('nth_weekday_of_month: 2nd-to-last Wed Aug = Aug 19', iso(rows[0].aug) === '2026-08-19', iso(rows[0].aug));
	report('nth_weekday_of_month: 2nd-to-last Wed Sep = Sep 23', iso(rows[0].sep) === '2026-09-23', iso(rows[0].sep));
	report('nth_weekday_of_month: 1st Wed Aug = Aug 5', iso(rows[0].first_wed) === '2026-08-05', iso(rows[0].first_wed));
	report('advance_due_date: weekday rule lands on next 2nd-to-last Wed', iso(rows[0].roll_rule) === '2026-09-23', iso(rows[0].roll_rule));
	report('advance_due_date: due_day preserved', iso(rows[0].roll_dueday) === '2026-09-15', iso(rows[0].roll_dueday));
}

// 14. Demo water bill is configured with the weekday rule after seed.
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select weekday, nth_occurrence, next_due_date
		from obligations where id = '71000000-0000-4000-8000-000000000028'`);
	report('water bill: weekday rule set in seed', rows[0].weekday === 3 && rows[0].nth_occurrence === -2, JSON.stringify(rows[0]));
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	report('water bill: next_due is 2nd-to-last Wed Aug', iso(rows[0].next_due_date) === '2026-08-19', iso(rows[0].next_due_date));
});

// 15. pay_obligation carries the rule through to the next occurrence.
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	let nd = null;
	await asUser(ownerId, async () => {
		await db.query(`select pay_obligation(
			'71000000-0000-4000-8000-000000000028', 95.00, '2026-08-19',
			'21000000-0000-4000-8000-000000000006', 'bank', 'W-PAY', 'check') as r`);
		const { rows } = await db.query(`select next_due_date from obligations
			where id = '71000000-0000-4000-8000-000000000028'`);
		nd = rows[0].next_due_date;
	});
	report('pay_obligation: water bill next due = Sep 23', iso(nd) === '2026-09-23', iso(nd));
}

// 16. est_amount: variable bills use the average of the last 3 payments once
//     3 exist; otherwise and for fixed bills they fall back to amount.
{
	await asUser(ownerId, async () => {
		const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));

		// Water bill 7100...0028 already has 2 payments (seed DEMO-003 + W-PAY).
		// Add a third and a fourth so the last-3 average diverges from amount.
		await db.query(`insert into payments (organization_id, obligation_id, amount, paid_date)
			values
			('11000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000028', 140.00, '2026-07-15'),
			('11000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000028', 120.00, '2026-07-22')`);

		const { rows: water } = await db.query(`select amount, variable_amount, est_amount
			from v_obligations where id = '71000000-0000-4000-8000-000000000028'`);
		report('est_amount: water bill variable_amount true', water[0].variable_amount === true);
		// last 3 by paid_date desc: 95 (08-19), 120 (07-22), 140 (07-15) -> avg = 118.33
		report('est_amount: water avg of last 3 = 118.33', Number(water[0].est_amount) === 118.33, `est=${water[0].est_amount}`);

		// Electric bill (seed) is variable too, but 0 payments -> falls back to amount.
		const { rows: electric } = await db.query(`select amount, est_amount
			from v_obligations where id = '71000000-0000-4000-8000-000000000027'`);
		report('est_amount: electric falls back to amount (no history)', Number(electric[0].est_amount) === 180.0, `est=${electric[0].est_amount}`);

		// Fixed loan-payment bill: est_amount === amount even with payments.
		const { rows: loan } = await db.query(`select amount, est_amount
			from v_obligations where id = '71000000-0000-4000-8000-000000000001'`);
		report('est_amount: fixed bill uses configured amount', Number(loan[0].est_amount) === Number(loan[0].amount), `amount=${loan[0].amount} est=${loan[0].est_amount}`);
	});
}

// 17. Admin org tooling (000013): invite by email + roster, admin-guarded.
await db.query(`insert into auth.users (id, email) values ('cccccccc-0000-4000-8000-000000000001', 'new@example.com') on conflict (id) do nothing`);
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select email, role from org_members_detail('11000000-0000-4000-8000-000000000001') order by email`);
	report('org_members_detail: admin sees roster with emails', rows.length === 2 && rows.some((r) => r.email === 'owner@example.com' && r.role === 'owner') && rows.some((r) => r.email === 'viewer@example.com' && r.role === 'viewer'), JSON.stringify(rows));

	const { rows: inv } = await db.query(`select invite_member('11000000-0000-4000-8000-000000000001', 'new@example.com', 'member') as id`);
	report('invite_member: creates membership by email', inv[0].id === 'cccccccc-0000-4000-8000-000000000001', inv[0].id);
	const { rows: mc } = await db.query(`select count(*)::int as c from org_members where organization_id = '11000000-0000-4000-8000-000000000001'`);
	report('invite_member: member added to org', Number(mc[0].c) === 3, `count=${mc[0].c}`);

	let dup = false;
	try {
		await db.query(`select invite_member('11000000-0000-4000-8000-000000000001', 'new@example.com', 'member')`);
	} catch {
		dup = true;
	}
	report('invite_member: duplicate invite rejected', dup);

	let noemail = false;
	try {
		await db.query(`select invite_member('11000000-0000-4000-8000-000000000001', 'ghost@example.com', 'member')`);
	} catch {
		noemail = true;
	}
	report('invite_member: unknown email rejected', noemail);
});

await asUser(viewerId, async () => {
	let denied = false;
	try {
		await db.query(`select invite_member('11000000-0000-4000-8000-000000000001', 'new@example.com', 'member')`);
	} catch {
		denied = true;
	}
	report('invite_member: non-admin denied', denied);

	let deniedRoster = false;
	try {
		await db.query(`select * from org_members_detail('11000000-0000-4000-8000-000000000001')`);
	} catch {
		deniedRoster = true;
	}
	report('org_members_detail: non-admin denied', deniedRoster);
});

// 18. Entity-scoped partner access (000014).
await asUser(ownerId, async () => {
	const { rows } = await db.query(`select grant_entity_access(
		'11000000-0000-4000-8000-000000000001', 'partner@example.com',
		'21000000-0000-4000-8000-000000000002') as uid`);
	report('grant_entity_access: returns partner uid', rows[0].uid === partnerId, rows[0].uid);

	const { rows: m } = await db.query(`select role from org_members
		where organization_id = '11000000-0000-4000-8000-000000000001' and user_id = $1`, [partnerId]);
	report('grant_entity_access: partner added as viewer member', m[0]?.role === 'viewer', JSON.stringify(m[0]));

	const { rows: d } = await db.query(`select email, entity_name, role
		from entity_access_detail('11000000-0000-4000-8000-000000000001')`);
	report('entity_access_detail: grant listed with entity + email', d.length === 1 && d[0].email === 'partner@example.com' && d[0].entity_name === 'Fritts Price LLC', JSON.stringify(d));

	await db.query(`select grant_entity_access(
		'11000000-0000-4000-8000-000000000001', 'partner@example.com',
		'21000000-0000-4000-8000-000000000002')`);
	report('grant_entity_access: duplicate grant no-ops', true);

	let noemail = false;
	try {
		await db.query(`select grant_entity_access(
			'11000000-0000-4000-8000-000000000001', 'ghost@example.com',
			'21000000-0000-4000-8000-000000000002')`);
	} catch {
		noemail = true;
	}
	report('grant_entity_access: unknown email rejected', noemail);
});

await asUser(viewerId, async () => {
	let denied = false;
	try {
		await db.query(`select grant_entity_access(
			'11000000-0000-4000-8000-000000000001', 'partner@example.com',
			'21000000-0000-4000-8000-000000000002')`);
	} catch {
		denied = true;
	}
	report('grant_entity_access: non-admin denied', denied);

	let deniedDetail = false;
	try {
		await db.query(`select * from entity_access_detail('11000000-0000-4000-8000-000000000001')`);
	} catch {
		deniedDetail = true;
	}
	report('entity_access_detail: non-admin denied', deniedDetail);
});

await asUser(partnerId, async () => {
	const { rows: es } = await db.query(`select id, name from ownership_entities order by id`);
	report('partner: only Fritts Price entity visible', es.length === 1 && es[0].id === '21000000-0000-4000-8000-000000000002', JSON.stringify(es));

	const { rows: props } = await db.query(`select id, name from properties`);
	report('partner: only Palmera House property visible', props.length === 1 && props[0].id === '31000000-0000-4000-8000-000000000001', JSON.stringify(props));

	const { rows: ob } = await db.query(`select id, name from obligations`);
	report('partner: only Palmera House tax obligation visible', ob.length === 1 && ob[0].id === '71000000-0000-4000-8000-000000000014', JSON.stringify(ob));

	const { rows: loans } = await db.query(`select count(*)::int as c from loans`);
	report('partner: no loans visible', Number(loans[0].c) === 0, `count=${loans[0].c}`);
	const { rows: tenants } = await db.query(`select count(*)::int as c from tenants`);
	report('partner: no tenants visible', Number(tenants[0].c) === 0, `count=${tenants[0].c}`);
	const { rows: pmts } = await db.query(`select count(*)::int as c from payments`);
	report('partner: no payments visible', Number(pmts[0].c) === 0, `count=${pmts[0].c}`);
	const { rows: bb } = await db.query(`select count(*)::int as c from billbacks`);
	report('partner: no billbacks visible', Number(bb[0].c) === 0, `count=${bb[0].c}`);

	const { rows: vs } = await db.query(`select property_count, loans_monthly
		from v_entity_summary where id = '21000000-0000-4000-8000-000000000002'`);
	report('partner: entity summary snapshot = Palmera House', Number(vs[0].property_count) === 1 && Number(vs[0].loans_monthly) === 0, JSON.stringify(vs));

	const { rows: cn } = await db.query(`select count(*)::int as c from v_cash_needed`);
	report('partner: cash needed shows only scoped obligations', Number(cn[0].c) === 1, `count=${cn[0].c}`);

	let denied = false;
	try {
		await db.query(`insert into ownership_entities (organization_id, name, entity_type)
			values ('11000000-0000-4000-8000-000000000001', 'Test', 'llc')`);
	} catch {
		denied = true;
	}
	report('partner: insert denied (read-only)', denied);

	let deniedPay = false;
	try {
		await db.query(`select pay_obligation(
			'71000000-0000-4000-8000-000000000014', 4200.00, '2026-08-10',
			'21000000-0000-4000-8000-000000000002', 'bank', 'P-TEST')`);
	} catch {
		deniedPay = true;
	}
	report('partner: pay_obligation denied (hardened)', deniedPay);
});

await asUser(ownerId, async () => {
	await db.query(`select revoke_entity_access('11000000-0000-4000-8000-000000000001', $1)`, [partnerId]);
	const { rows: g } = await db.query(`select count(*)::int as c from entity_access
		where organization_id = '11000000-0000-4000-8000-000000000001' and user_id = $1`, [partnerId]);
	report('revoke_entity_access: grant removed', Number(g[0].c) === 0, `count=${g[0].c}`);
	const { rows: mm } = await db.query(`select count(*)::int as c from org_members
		where organization_id = '11000000-0000-4000-8000-000000000001' and user_id = $1`, [partnerId]);
	report('revoke_entity_access: viewer membership removed', Number(mm[0].c) === 0, `count=${mm[0].c}`);
});

await asUser(partnerId, async () => {
	const { rows } = await db.query(`select count(*)::int as c from ownership_entities`);
	report('revoked partner: sees nothing', Number(rows[0].c) === 0, `count=${rows[0].c}`);
});

// 19. Quarterly tax installments (000015).
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows } = await db.query(`select
		advance_due_date('2026-11-15', 'quarterly', null, 15, null, null, '{1,3,5,11}') as nov,
		advance_due_date('2026-05-15', 'quarterly', null, 15, null, null, '{1,3,5,11}') as late_may,
		advance_due_date('2026-12-01', 'quarterly', null, 15, null, null, '{1,3,5,11}') as late_nov`);
	report('advance_due_date: installment Nov 15 -> Jan 15', iso(rows[0].nov) === '2027-01-15', iso(rows[0].nov));
	report('advance_due_date: late May pay -> next Nov 15', iso(rows[0].late_may) === '2026-11-15', iso(rows[0].late_may));
	report('advance_due_date: late Nov pay -> next Jan 15', iso(rows[0].late_nov) === '2027-01-15', iso(rows[0].late_nov));
}

await asUser(ownerId, async () => {
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: tax } = await db.query(`select amount, frequency, installment_months, due_day, next_due_date
		from obligations where id = '71000000-0000-4000-8000-000000000014'`);
	report('tax obligation: quarterly {1,3,5,11} due 15', tax[0].frequency === 'quarterly' && tax[0].installment_months[0] === 1 && tax[0].due_day === 15, JSON.stringify(tax[0]));
	report('tax obligation: amount = annual/4 = 1050', Number(tax[0].amount) === 1050, `amount=${tax[0].amount}`);
	report('tax obligation: next due = 2026-11-15', iso(tax[0].next_due_date) === '2026-11-15', iso(tax[0].next_due_date));

	const { rows: vp } = await db.query(`select annual_tax, tax_next_due_date, tax_next_amount
		from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('v_properties: Palmera annual_tax = 4200', Number(vp[0].annual_tax) === 4200, `annual_tax=${vp[0].annual_tax}`);
	report('v_properties: tax_next_due_date = 2026-11-15', iso(vp[0].tax_next_due_date) === '2026-11-15', iso(vp[0].tax_next_due_date));
	report('v_properties: tax_next_amount = 1050', Number(vp[0].tax_next_amount) === 1050, `amount=${vp[0].tax_next_amount}`);

	const { rows: vp2 } = await db.query(`select annual_tax, tax_next_due_date
		from v_properties where id = '31000000-0000-4000-8000-000000000003'`);
	report('v_properties: no-tax property shows nulls', vp2[0].annual_tax === null && vp2[0].tax_next_due_date === null, JSON.stringify(vp2[0]));

	const { rows: pay } = await db.query(`select pay_obligation(
		'71000000-0000-4000-8000-000000000014', 1050.00, '2026-11-15',
		'21000000-0000-4000-8000-000000000002', 'bank', 'TAX-Q1') as r`);
	report('pay_obligation: tax installment returns next = Jan 15', iso(pay[0].r.next_due_date) === '2027-01-15', iso(pay[0].r.next_due_date));
	const { rows: ob } = await db.query(`select status, next_due_date from obligations where id = '71000000-0000-4000-8000-000000000014'`);
	report('pay_obligation: tax stays open after installment', ob[0].status === 'open', ob[0].status);
	report('pay_obligation: next due advanced to Jan 15', iso(ob[0].next_due_date) === '2027-01-15', iso(ob[0].next_due_date));
});

// 20. Billback redesign (000016).
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));

	// New columns + nullable to_ownership_entity_id exist.
	const { rows: cols } = await db.query(`select column_name from information_schema.columns
		where table_name = 'billbacks'
		and column_name in ('check_number', 'vendor_id', 'property_id', 'paid_amount', 'markup_percent', 'responsibility_type')`);
	report('billbacks: check-register columns added', cols.length === 6, `count=${cols.length}`);

	const { rows: allocTable } = await db.query(`select to_regclass('public.billback_allocations') as t`);
	report('billbacks: allocations table exists', allocTable[0].t === 'billback_allocations', String(allocTable[0].t));

	// Seed allocations drive responsible_party_display.
	const { rows: vb } = await db.query(`select id, responsible_party_display from v_billbacks
		where id in ('81000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000002')
		order by id`);
	report('v_billbacks: responsible_party_display from allocations', vb.length === 2 && vb[0].responsible_party_display.includes('JenCal'), JSON.stringify(vb));
}

await asUser(ownerId, async () => {
	// Create a split billback with markup + a tenant allocation, then verify view math.
	const { rows: ins } = await db.query(`insert into billbacks
		(organization_id, from_ownership_entity_id, description, amount, paid_amount, markup_percent,
		 check_number, property_id, responsibility_type, issued_date)
		values ('11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006',
			'[TEST] Split HVAC (tenant 70 / landlord 30)', 230.00, 200.00, 15.00,
			'TEST-100', '31000000-0000-4000-8000-000000000002', 'split', '2026-08-10')
		returning id`);
	const bbId = ins[0].id;

	await db.query(`insert into billback_allocations
		(organization_id, billback_id, responsible_type, tenant_id, ownership_entity_id, allocation_type, percentage, amount)
		values
		('11000000-0000-4000-8000-000000000001', '${bbId}', 'tenant', '51000000-0000-4000-8000-000000000001', null, 'percent', 70.00, 161.00),
		('11000000-0000-4000-8000-000000000001', '${bbId}', 'ownership_entity', null, '21000000-0000-4000-8000-000000000002', 'percent', 30.00, 69.00)`);

	const { rows: check } = await db.query(`select amount, paid_amount, markup_percent, responsibility_type from billbacks where id = '${bbId}'`);
	report('billback: markup baked into amount owed', Number(check[0].amount) === 230 && Number(check[0].paid_amount) === 200 && Number(check[0].markup_percent) === 15, JSON.stringify(check[0]));

	const { rows: vb } = await db.query(`select responsible_party_display, balance, is_outstanding from v_billbacks where id = '${bbId}'`);
	report('v_billbacks: split display lists both parties', vb[0].responsible_party_display.includes('Rivera') && vb[0].responsible_party_display.includes('Fritts Price LLC'), vb[0].responsible_party_display);
	report('v_billbacks: balance = amount (no payments)', Number(vb[0].balance) === 230 && vb[0].is_outstanding, `balance=${vb[0].balance}`);

	// Delete a billback that has payments -> cascade removes them (000016 fix).
	await db.query(`insert into payments (organization_id, billback_id, amount, paid_date)
		values ('11000000-0000-4000-8000-000000000001', '${bbId}', 100.00, '2026-08-15')`);
	await db.query(`delete from billbacks where id = '${bbId}'`);
	const { rows: leftover } = await db.query(`select count(*)::int as c from payments
		where organization_id = '11000000-0000-4000-8000-000000000001' and billback_id = '${bbId}'`);
	report('delete billback with payments: cascades payments cleanly', Number(leftover[0].c) === 0, `count=${leftover[0].c}`);
	const { rows: leftoverAlloc } = await db.query(`select count(*)::int as c from billback_allocations where billback_id = '${bbId}'`);
	report('delete billback: cascades allocations cleanly', Number(leftoverAlloc[0].c) === 0, `count=${leftoverAlloc[0].c}`);

	// Tenant-only billback with to_ownership_entity_id null.
	const { rows: ins2 } = await db.query(`insert into billbacks
		(organization_id, from_ownership_entity_id, to_ownership_entity_id, description, amount, paid_amount, responsibility_type, issued_date)
		values ('11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null,
			'[TEST] Tenant reimburse water', 95.00, 95.00, 'tenant', '2026-08-10')
		returning id`);
	const bb2Id = ins2[0].id;
	await db.query(`insert into billback_allocations (organization_id, billback_id, responsible_type, tenant_id, allocation_type, amount)
		values ('11000000-0000-4000-8000-000000000001', '${bb2Id}', 'tenant', '51000000-0000-4000-8000-000000000002', 'amount', 95.00)`);
	const { rows: vb2 } = await db.query(`select responsible_party_display from v_billbacks where id = '${bb2Id}'`);
	report('v_billbacks: tenant-only billback displays tenant', vb2[0].responsible_party_display.includes('Maria'), vb2[0].responsible_party_display);
	await db.query(`delete from billbacks where id = '${bb2Id}'`);
});

// 21. Interval days (000018): bills due N days after the previous bill.
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows } = await db.query(`select
		advance_due_date('2026-08-20', 'monthly', null, null, null, null, null, 29) as plus29,
		advance_due_date('2026-11-15', 'quarterly', null, 15, null, null, '{1,3,5,11}', 45) as days_beat_installment,
		advance_due_date('2026-08-15', 'monthly', null, null, 3, -2, null, null) as weekday_still_works,
		advance_due_date('2026-08-15', 'monthly', null, 15, null, null, null, null) as due_day_still_works`);
	report('advance_due_date: interval_days = +29 days (Aug 20 -> Sep 18)', iso(rows[0].plus29) === '2026-09-18', iso(rows[0].plus29));
	report('advance_due_date: interval_days beats installment rule', iso(rows[0].days_beat_installment) === '2026-12-30', iso(rows[0].days_beat_installment));
	report('advance_due_date: weekday rule unaffected by 8-arg default', iso(rows[0].weekday_still_works) === '2026-09-23', iso(rows[0].weekday_still_works));
	report('advance_due_date: due_day rule unaffected by 8-arg default', iso(rows[0].due_day_still_works) === '2026-09-15', iso(rows[0].due_day_still_works));
}

await asUser(ownerId, async () => {
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: seedEl } = await db.query(`select interval_days, due_day from obligations
		where id = '71000000-0000-4000-8000-000000000027'`);
	report('electric obligation: seed sets interval_days = 29, no due_day', Number(seedEl[0].interval_days) === 29 && seedEl[0].due_day === null, JSON.stringify(seedEl[0]));

	const { rows: pay } = await db.query(`select pay_obligation(
		'71000000-0000-4000-8000-000000000027', 180.00, '2026-08-20',
		'21000000-0000-4000-8000-000000000006', 'bank', 'ELEC-01') as r`);
	report('pay_obligation: electric advances +29 days (next = 2026-09-18)', iso(pay[0].r.next_due_date) === '2026-09-18', iso(pay[0].r.next_due_date));
	const { rows: ob } = await db.query(`select status, next_due_date from obligations where id = '71000000-0000-4000-8000-000000000027'`);
	report('pay_obligation: electric stays open after pay', ob[0].status === 'open', ob[0].status);
});

const failed = results.filter((r) => !r.pass);
console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
process.exit(failed.length ? 1 : 0);
