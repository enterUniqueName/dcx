// Upgrade-path test for the post-000009 migrations.
//
// Models the LIVE DB the way the user actually upgrades it:
//   1. migrations up to 000009 applied
//   2. the 000009-era seed applied (commit 5e0203c, the last seed before the
//      lease/rent model — this is the state the live DB was in)
//   3. the new migrations pasted on top (000010, 000011, 000012)
//   4. the working-copy seed re-run (same as the user re-running seed.sql)
// Verifies columns are dropped/added, new tables exist, nickname backfilled,
// and the read-model views come up populated.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIGRATIONS = join(REPO, 'supabase/migrations');
const db = new PGlite();
const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));

const results = [];
function report(name, pass, extra = '') {
	results.push({ name, pass, extra });
	console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${extra ? '  — ' + extra : ''}`);
}

await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create schema auth;
  create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
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

// Apply up to 000009 (the state the LIVE DB is in).
for (const m of ['000001_init_schema.sql', '000002_rls.sql', '000003_views.sql', '000004_functions.sql', '000005_storage.sql', '000006_properties_nickname.sql', '000007_cash_needed_org_id.sql', '000008_nth_weekday.sql', '000009_variable_amount.sql']) {
	try {
		await db.exec(readFileSync(join(MIGRATIONS, m), 'utf8'));
		report(`pre-upgrade migration ${m}`, true);
	} catch (e) {
		report(`pre-upgrade migration ${m}`, false, e.message);
		process.exit(1);
	}
}

// Seed with the 000009-era seed (commit 5e0203c) — simulates the live data
// before the 000010 upgrade (the working-copy seed now carries the
// lease/rent model).
const headSeed = execFileSync('git', ['show', '5e0203c:supabase/seed.sql'], { cwd: REPO, encoding: 'utf8' });
try {
	await db.exec(headSeed);
	report('000009-era seed applied (move_in_date + ein/status present)', true);
} catch (e) {
	report('000009-era seed applied', false, e.message);
	process.exit(1);
}

// Confirm the preconditions the migration must handle.
{
	const { rows } = await db.query(`select
		exists (select 1 from information_schema.columns where table_name = 'tenants' and column_name = 'move_in_date') as has_move_in,
		exists (select 1 from information_schema.columns where table_name = 'ownership_entities' and column_name = 'ein') as has_ein`);
	report('precondition: live schema still has move_in_date + ein', rows[0].has_move_in === true && rows[0].has_ein === true);
}

// Now apply 000010 exactly as the user pastes it.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000010_leases_rent.sql'), 'utf8'));
	report('migration 000010_leases_rent.sql', true);
} catch (e) {
	report('migration 000010_leases_rent.sql', false, e.message);
	console.error(e);
	process.exit(1);
}

{
	const { rows } = await db.query(`select
		exists (select 1 from information_schema.columns where table_name = 'tenants' and column_name = 'move_in_date') as has_move_in,
		exists (select 1 from information_schema.columns where table_name = 'tenants' and column_name = 'responsible_electric') as has_flag,
		exists (select 1 from information_schema.columns where table_name = 'ownership_entities' and column_name = 'ein') as has_ein,
		exists (select 1 from information_schema.columns where table_name = 'ownership_entities' and column_name = 'status') as has_entity_status`);
	report('000010: move_in_date + ein + entity status dropped', rows[0].has_move_in === false && rows[0].has_ein === false && rows[0].has_entity_status === false);
	report('000010: tenants responsibility flag added', rows[0].has_flag === true);
	const { rows: t } = await db.query(`select count(*)::int as c from information_schema.tables where table_name in ('leases', 'rent_schedule')`);
	report('000010: leases + rent_schedule tables exist', Number(t[0].c) === 2, `tables=${t[0].c}`);
}

// Apply 000011 (v_properties nickname fix) on top of the migrated state.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000011_v_properties_nickname.sql'), 'utf8'));
	report('migration 000011_v_properties_nickname.sql', true);
} catch (e) {
	report('migration 000011_v_properties_nickname.sql', false, e.message);
	process.exit(1);
}
{
	const { rows } = await db.query(`select nickname from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('000011 upgrade: v_properties.nickname = Palmera House', rows[0].nickname === 'Palmera House', JSON.stringify(rows[0]));
}

// Apply 000012 (loans nickname) — backfills from the pre-upgrade seed's
// "nickname: ..." notes prefix.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000012_loans_nickname.sql'), 'utf8'));
	report('migration 000012_loans_nickname.sql', true);
} catch (e) {
	report('migration 000012_loans_nickname.sql', false, e.message);
	process.exit(1);
}
{
	const { rows } = await db.query(`select nickname, notes from v_loans where id = '41000000-0000-4000-8000-000000000001'`);
	report('000012 upgrade: nickname backfilled from old notes', rows[0].nickname === 'Bus. Term R/E 360 | Thomson #2', JSON.stringify(rows[0]));
	report('000012 upgrade: notes prefix stripped', rows[0].notes === null, `notes=${JSON.stringify(rows[0].notes)}`);
	const { rows: vlc } = await db.query(`select count(*)::int as c from v_loans where nickname is not null`);
	report('000012 upgrade: all 13 nicknames present', Number(vlc[0].c) === 13, `count=${vlc[0].c}`);
}

// Apply 000013 (admin org tooling).
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000013_org_admin.sql'), 'utf8'));
	report('migration 000013_org_admin.sql', true);
} catch (e) {
	report('migration 000013_org_admin.sql', false, e.message);
	process.exit(1);
}// Provision an owner (simulates the seed's provisioning snippet) and check the
// roster + invite RPCs work on the upgraded schema.
await db.query(`insert into auth.users (id, email) values ('aaaaaaaa-0000-4000-8000-000000000001', 'owner@example.com') on conflict (id) do nothing`);
await db.query(`insert into org_members (organization_id, user_id, role)
  select '11000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'owner'
  on conflict (organization_id, user_id) do nothing`);
await db.query(`select set_config('auth.test_uid', 'aaaaaaaa-0000-4000-8000-000000000001', false)`);
await db.query('set role authenticated');
{
	const { rows } = await db.query(`select email, role from org_members_detail('11000000-0000-4000-8000-000000000001')`);
	report('000013 upgrade: admin roster works', rows.length === 1 && rows[0].email === 'owner@example.com' && rows[0].role === 'owner', JSON.stringify(rows));
}
await db.query('reset role');

// Apply 000014 (entity-scoped partner access) on the live state.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000014_entity_access.sql'), 'utf8'));
	report('migration 000014_entity_access.sql', true);
} catch (e) {
	report('migration 000014_entity_access.sql', false, e.message);
	process.exit(1);
}
{
	// Grant a partner the Fritts Price entity and confirm the upgraded schema
	// scopes reads (run here, pre-seed-rerun, against the 000009-era data).
	await db.query(`insert into auth.users (id, email) values ('bbbbbbbb-0000-4000-8000-000000000001', 'partner@example.com') on conflict (id) do nothing`);
	await db.query(`select set_config('auth.test_uid', 'aaaaaaaa-0000-4000-8000-000000000001', false)`);
	await db.query('set role authenticated');
	await db.query(`select grant_entity_access('11000000-0000-4000-8000-000000000001', 'partner@example.com', '21000000-0000-4000-8000-000000000002')`);
	await db.query('reset role');

	await db.query(`select set_config('auth.test_uid', 'bbbbbbbb-0000-4000-8000-000000000001', false)`);
	await db.query('set role authenticated');
	const { rows: es } = await db.query(`select id, name from ownership_entities`);
	report('000014 upgrade: partner sees only Fritts Price entity', es.length === 1 && es[0].id === '21000000-0000-4000-8000-000000000002', JSON.stringify(es));
	const { rows: ob } = await db.query(`select id from obligations`);
	report('000014 upgrade: partner sees only scoped obligations', ob.length === 1 && ob[0].id === '71000000-0000-4000-8000-000000000014', JSON.stringify(ob));
	await db.query('reset role');
}

// Apply 000015 (tax installments) on the live state. The 000009-era seed
// carried annual tax obligations (Dec 5) and the annual figure in property
// notes; the migration must convert them and backfill annual_tax.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000015_tax_installments.sql'), 'utf8'));
	report('migration 000015_tax_installments.sql', true);
} catch (e) {
	report('migration 000015_tax_installments.sql', false, e.message);
	process.exit(1);
}
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: vp } = await db.query(`select annual_tax, tax_next_due_date, tax_next_amount
		from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('000015 upgrade: annual_tax backfilled from notes = 4200', Number(vp[0].annual_tax) === 4200, `annual_tax=${vp[0].annual_tax}`);
	report('000015 upgrade: v_properties exposes next tax installment', iso(vp[0].tax_next_due_date) === '2026-11-15' && Number(vp[0].tax_next_amount) === 1050, JSON.stringify(vp[0]));
	const { rows: tax } = await db.query(`select frequency, installment_months, amount, next_due_date
		from obligations where id = '71000000-0000-4000-8000-000000000014'`);
	report('000015 upgrade: tax obligation converted to quarterly', tax[0].frequency === 'quarterly' && tax[0].installment_months[0] === 1, JSON.stringify(tax[0]));
	report('000015 upgrade: tax amount = annual/4 = 1050', Number(tax[0].amount) === 1050, `amount=${tax[0].amount}`);
	report('000015 upgrade: next installment due = 2026-11-15', iso(tax[0].next_due_date) === '2026-11-15', iso(tax[0].next_due_date));
	const { rows: notes } = await db.query(`select notes from properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('000015 upgrade: tax note stripped from property', notes[0].notes === null, `notes=${JSON.stringify(notes[0].notes)}`);
}

// Apply 000016 (billback redesign) on the live state.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000016_billback_redesign.sql'), 'utf8'));
	report('migration 000016_billback_redesign.sql', true);
} catch (e) {
	report('migration 000016_billback_redesign.sql', false, e.message);
	process.exit(1);
}
{
	const { rows: cols } = await db.query(`select column_name from information_schema.columns
		where table_name = 'billbacks'
		and column_name in ('check_number', 'vendor_id', 'property_id', 'paid_amount', 'markup_percent', 'responsibility_type')`);
	report('000016 upgrade: check-register columns added', cols.length === 6, `count=${cols.length}`);
	const { rows: alloc } = await db.query(`select to_regclass('public.billback_allocations') as t`);
	report('000016 upgrade: allocations table exists', alloc[0].t === 'billback_allocations', String(alloc[0].t));
	const { rows: vb } = await db.query(`select responsible_party_display from v_billbacks where id = '81000000-0000-4000-8000-000000000001'`);
	report('000016 upgrade: v_billbacks has responsible_party_display', (vb[0]?.responsible_party_display ?? '').includes('JenCal'), JSON.stringify(vb));
}

// Apply 000017 (drop properties.nickname) on the live state.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000017_remove_property_nickname.sql'), 'utf8'));
	report('migration 000017_remove_property_nickname.sql', true);
} catch (e) {
	report('migration 000017_remove_property_nickname.sql', false, e.message);
	process.exit(1);
}
{
	const { rows: cols } = await db.query(`select count(*)::int as c from information_schema.columns
		where table_name = 'properties' and column_name = 'nickname'`);
	report('000017 upgrade: properties.nickname column dropped', Number(cols[0].c) === 0, `count=${cols[0].c}`);
	const { rows: vp } = await db.query(`select property_name from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('000017 upgrade: v_properties.property_name = name', vp[0].property_name === '2307 Bedford Ave', `property_name=${vp[0].property_name}`);
	const { rows: vl } = await db.query(`select property_name from v_loans where id = '41000000-0000-4000-8000-000000000001'`);
	report('000017 upgrade: v_loans.property_name = name', vl[0].property_name === '1915 Thomson Dr', `property_name=${vl[0].property_name}`);
	const { rows: vt } = await db.query(`select property_name from v_tenants where id = '51000000-0000-4000-8000-000000000001'`);
	report('000017 upgrade: v_tenants.property_name = name', vt[0].property_name === '309 Hancock St', `property_name=${vt[0].property_name}`);
}

// Apply 000018 (interval_days) on the live state.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000018_interval_days.sql'), 'utf8'));
	report('migration 000018_interval_days.sql', true);
} catch (e) {
	report('migration 000018_interval_days.sql', false, e.message);
	process.exit(1);
}
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: cols } = await db.query(`select count(*)::int as c from information_schema.columns
		where table_name = 'obligations' and column_name = 'interval_days'`);
	report('000018 upgrade: obligations.interval_days column added', Number(cols[0].c) === 1, `count=${cols[0].c}`);
	const { rows: el } = await db.query(`select interval_days, due_day from obligations
		where id = '71000000-0000-4000-8000-000000000027'`);
	report('000018 upgrade: live electric converted to interval_days = 29', Number(el[0].interval_days) === 29 && el[0].due_day === null, JSON.stringify(el[0]));
	const { rows: ad } = await db.query(`select advance_due_date('2026-08-20', 'monthly', null, null, null, null, null, 29) as d`);
	report('000018 upgrade: advance_due_date honors interval_days', iso(ad[0].d) === '2026-09-18', iso(ad[0].d));
}

// Apply 000019 (bill cycles) on the live state. The 000009-era seed carried
// plain one_time obligations as obligations rows; the migration must split
// templates from bills (kind/series_id) and backfill one_time rows to bills.
try {
	await db.exec(readFileSync(join(MIGRATIONS, '000019_bill_cycles.sql'), 'utf8'));
	report('migration 000019_bill_cycles.sql', true);
} catch (e) {
	report('migration 000019_bill_cycles.sql', false, e.message);
	console.error(e);
	process.exit(1);
}
{
	const iso = (d) => (d instanceof Date ? d.toISOString().slice(0, 10) : String(d));
	const { rows: cols } = await db.query(`select count(*)::int as c from information_schema.columns
		where table_name = 'obligations' and column_name in ('kind', 'series_id', 'paid_amount', 'paid_date', 'funding_entity_id')`);
	report('000019 upgrade: kind/series_id/payment columns added', Number(cols[0].c) === 5, `count=${cols[0].c}`);
	const { rows: one_time } = await db.query(`select count(*)::int as c from obligations
		where kind = 'bill' and frequency = 'one_time'`);
	report('000019 upgrade: one_time rows all backfilled to bills (0 one_time in live seed)', Number(one_time[0].c) === 0, `count=${one_time[0].c}`);
	const { rows: tpl } = await db.query(`select count(*)::int as c from obligations where kind = 'template'`);
	report('000019 upgrade: recurring rows are templates', Number(tpl[0].c) > 0, `count=${tpl[0].c}`);
}

// Re-run the CURRENT seed (working copy) over the fully migrated live data —
// the same thing the user does after pasting the migrations. Runs last
// because the loans insert now carries the nickname column (000012).
// Clear any leftover auth.test_uid from the 000013/000014 blocks so the seed's
// generate_bills call runs in the admin context.
await db.query(`select set_config('auth.test_uid', '', false)`);
try {
	await db.exec(readFileSync(join(REPO, 'supabase/seed.sql'), 'utf8'));
	report('current seed re-applied over migrations', true);
} catch (e) {
	report('current seed re-applied over migrations', false, e.message);
	console.error(e);
	process.exit(1);
}
{
	const { rows: l } = await db.query(`select count(*)::int as c from leases`);
	report('000010 upgrade: leases populated', Number(l[0].c) === 6, `count=${l[0].c}`);
	const { rows: r } = await db.query(`select count(*)::int as c from rent_schedule`);
	report('000010 upgrade: rent_schedule populated', Number(r[0].c) === 10, `count=${r[0].c}`);
	const { rows: es } = await db.query(`select count(*)::int as c from v_entity_summary`);
	report('000010 upgrade: v_entity_summary returns 7 rows', Number(es[0].c) === 7, `count=${es[0].c}`);
	const { rows: vl } = await db.query(`select nickname from v_loans where id = '41000000-0000-4000-8000-000000000001'`);
	report('current seed re-run: loan nickname intact', vl[0].nickname === 'Bus. Term R/E 360 | Thomson #2', JSON.stringify(vl[0]));
	const { rows: at } = await db.query(`select annual_tax from v_properties where id = '31000000-0000-4000-8000-000000000001'`);
	report('current seed re-run: annual_tax intact (on conflict do nothing)', Number(at[0].annual_tax) === 4200, `annual_tax=${at[0].annual_tax}`);
	const { rows: el } = await db.query(`select interval_days, due_day from obligations
		where id = '71000000-0000-4000-8000-000000000027'`);
	report('current seed re-run: electric still interval_days = 29 (on conflict do nothing)', Number(el[0].interval_days) === 29 && el[0].due_day === null, JSON.stringify(el[0]));
	const { rows: bills } = await db.query(`select count(*)::int as c from obligations
		where kind = 'bill' and frequency <> 'one_time' and series_id is not null`);
	report('current seed re-run: generate_bills materialized bills per series', Number(bills[0].c) > 0, `count=${bills[0].c}`);
	const { rows: vp } = await db.query(`select tax_next_due_date from v_properties
		where id = '31000000-0000-4000-8000-000000000001'`);
	report('current seed re-run: v_properties tax reads the generated bill', iso(vp[0].tax_next_due_date) === '2026-11-15', iso(vp[0].tax_next_due_date));
}

const failed = results.filter((r) => !r.pass);
console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
process.exit(failed.length ? 1 : 0);
