import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const db = new PGlite();

await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create schema auth;
  create table auth.users (id uuid primary key, email text);
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

for (const m of ['000001_init_schema.sql', '000002_rls.sql', '000003_views.sql', '000004_functions.sql', '000005_storage.sql', '000006_properties_nickname.sql', '000007_cash_needed_org_id.sql', '000008_nth_weekday.sql', '000009_variable_amount.sql']) {
	await db.exec(readFileSync(join(REPO, 'supabase/migrations', m), 'utf8'));
}
await db.exec(execFileSync('git', ['show', '5e0203c:supabase/seed.sql'], { cwd: REPO, encoding: 'utf8' }));

const mig10 = readFileSync(join(REPO, 'supabase/migrations', '000010_leases_rent.sql'), 'utf8');
await db.exec(mig10);
await db.exec(mig10);

const mig11 = readFileSync(join(REPO, 'supabase/migrations', '000011_v_properties_nickname.sql'), 'utf8');
await db.exec(mig11);
await db.exec(mig11);

const mig12 = readFileSync(join(REPO, 'supabase/migrations', '000012_loans_nickname.sql'), 'utf8');
await db.exec(mig12);
await db.exec(mig12);

const mig13 = readFileSync(join(REPO, 'supabase/migrations', '000013_org_admin.sql'), 'utf8');
await db.exec(mig13);
await db.exec(mig13);

const mig14 = readFileSync(join(REPO, 'supabase/migrations', '000014_entity_access.sql'), 'utf8');
await db.exec(mig14);
await db.exec(mig14);

const mig15 = readFileSync(join(REPO, 'supabase/migrations', '000015_tax_installments.sql'), 'utf8');
await db.exec(mig15);
await db.exec(mig15);

const mig16 = readFileSync(join(REPO, 'supabase/migrations', '000016_billback_redesign.sql'), 'utf8');
await db.exec(mig16);
await db.exec(mig16);

const mig17 = readFileSync(join(REPO, 'supabase/migrations', '000017_remove_property_nickname.sql'), 'utf8');
await db.exec(mig17);
await db.exec(mig17);

const mig18 = readFileSync(join(REPO, 'supabase/migrations', '000018_interval_days.sql'), 'utf8');
await db.exec(mig18);
await db.exec(mig18);

const mig19 = readFileSync(join(REPO, 'supabase/migrations', '000019_bill_cycles.sql'), 'utf8');
await db.exec(mig19);
await db.exec(mig19);

const { rows } = await db.query(
	`select
	  (select count(*)::int from v_obligations where est_amount is null) as null_est,
	  (select count(*)::int from information_schema.tables where table_name in ('leases', 'rent_schedule')) as lease_tables,
	  (select count(*)::int from v_entity_summary) as entity_summary_rows,
	  (select count(*)::int from information_schema.columns where table_name = 'tenants' and column_name = 'move_in_date') as move_in_left,
	  (select count(*)::int from information_schema.columns where table_name = 'v_properties' and column_name = 'nickname') as vprop_nickname,
	  (select count(*)::int from information_schema.columns where table_name = 'properties' and column_name = 'nickname') as prop_nickname,
	  (select count(*)::int from information_schema.columns where table_name = 'v_loans' and column_name = 'nickname') as vloan_nickname,
	  (select count(*)::int from loans where nickname is null) as loan_nickname_null,
	  (select count(*)::int from pg_proc where proname in ('invite_member', 'org_members_detail')) as admin_fns,
	  (select count(*)::int from information_schema.tables where table_name = 'entity_access') as entity_access_table,
	  (select count(*)::int from pg_proc where proname in ('grant_entity_access', 'revoke_entity_access', 'entity_access_detail', 'is_entity_scoped', 'visible_entities')) as scope_fns,
	  (select count(*)::int from properties where annual_tax is not null) as annual_tax_filled,
	  (select count(*)::int from obligations where category = 'tax' and installment_months is not null) as quarterly_tax,
	  (select count(*)::int from obligations where category = 'tax' and installment_months is null) as non_installment_tax,
	  (select amount::numeric from obligations where id = '71000000-0000-4000-8000-000000000014') as palmera_tax,
	  (select count(*)::int from information_schema.columns where table_name = 'v_properties' and column_name = 'tax_next_due_date') as vprop_tax_col,
	  (select count(*)::int from information_schema.tables where table_name = 'billback_allocations') as alloc_table,
	  (select count(*)::int from information_schema.columns where table_name = 'billbacks' and column_name in ('check_number', 'vendor_id', 'property_id', 'paid_amount', 'markup_percent', 'responsibility_type')) as bb_new_cols,
	  (select count(*)::int from information_schema.columns where table_name = 'obligations' and column_name = 'interval_days') as idays_col,
	  (select interval_days::int from obligations where id = '71000000-0000-4000-8000-000000000027') as idays_electric,
	  (select count(*)::int from obligations where category = 'electric' and due_day is not null) as electric_due_day,
	  (select count(*)::int from information_schema.columns where table_name = 'obligations' and column_name in ('kind', 'series_id', 'paid_amount', 'paid_date', 'funding_entity_id')) as billcycle_cols,
	  (select count(*)::int from obligations where kind = 'bill' and series_id is null) as bill_no_series,
	  (select count(*)::int from obligations where kind = 'template' and status = 'paid') as tpl_paid`
);
const ok = rows[0].null_est === 0 && rows[0].lease_tables === 2 && rows[0].entity_summary_rows === 7 && rows[0].move_in_left === 0 && rows[0].vprop_nickname === 0 && rows[0].prop_nickname === 0 && rows[0].vloan_nickname === 1 && rows[0].loan_nickname_null === 0 && rows[0].admin_fns === 2 && rows[0].entity_access_table === 1 && rows[0].scope_fns === 5 && rows[0].annual_tax_filled === 13 && rows[0].quarterly_tax === 13 && rows[0].non_installment_tax === 0 && Number(rows[0].palmera_tax) === 1050 && rows[0].vprop_tax_col === 1 && rows[0].alloc_table === 1 && rows[0].bb_new_cols === 6 && rows[0].idays_col === 1 && Number(rows[0].idays_electric) === 29 && rows[0].electric_due_day === 0 && rows[0].billcycle_cols === 5 && rows[0].bill_no_series === 0 && rows[0].tpl_paid === 0;
console.log(ok ? 'PASS  idempotent re-run clean' : 'FAIL  ' + JSON.stringify(rows[0]));
process.exit(ok ? 0 : 1);
