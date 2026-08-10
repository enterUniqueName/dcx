-- 000010_leases_rent.sql
-- Tenant/lease model and the ownership-entity summary read model.
--
-- * tenants: drop move_in_date; add who-pays responsibility flags (lease
--   knowledge, for visibility). Defaults reflect the common case — the
--   landlord pays water/HVAC/CAM, the tenant pays electric/internet — and
--   the exceptions flip individual tenants.
-- * leases: 1:1 with a tenant (a table so a future renewal keeps history),
--   holding the Google Drive link and lease term. The rent numbers live in
--   rent_schedule instead, because they change over time.
-- * rent_schedule: one row per rent period. period_end null = the current
--   period, so an intro rate is a bounded row followed by the base row, and
--   each CPI adjustment is a new row with cpi_percent set. Reading the rows
--   in period_start order is the full rent history / increase-over-time.
-- * ownership_entities: drop ein and status — replaced by the v_entity_summary
--   rollups (properties, rent, loan payments, billbacks owed, net per month).
--
-- Read-model changes: v_tenants gains lease + current-rent columns and
-- v_entity_summary is the entity collection's new source.

-- v_tenants selects t.*, so it must be dropped before the tenant column
-- changes and recreated after.
drop view if exists v_tenants;
-- v_entity_summary is dropped first so a re-run (idempotent re-apply) works.
drop view if exists v_entity_summary;

-- ---------------------------------------------------------------------------
-- tenants
-- ---------------------------------------------------------------------------
alter table tenants drop column if exists move_in_date;

alter table tenants add column if not exists responsible_water boolean not null default false;
alter table tenants add column if not exists responsible_electric boolean not null default true;
alter table tenants add column if not exists responsible_internet boolean not null default true;
alter table tenants add column if not exists responsible_hvac boolean not null default false;
alter table tenants add column if not exists responsible_cam boolean not null default false;

-- ---------------------------------------------------------------------------
-- leases (1:1 with tenant; unique tenant_id)
-- ---------------------------------------------------------------------------
create table if not exists leases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  tenant_id uuid not null unique references tenants(id) on delete cascade,
  url text,
  lease_start date,
  lease_end date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists leases_org_idx on leases (organization_id);

-- ---------------------------------------------------------------------------
-- rent_schedule
-- ---------------------------------------------------------------------------
create table if not exists rent_schedule (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  period_start date not null,
  period_end date,
  amount numeric(12, 2) not null check (amount >= 0),
  cpi_percent numeric(6, 3),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists rent_schedule_org_idx on rent_schedule (organization_id);
create index if not exists rent_schedule_tenant_idx on rent_schedule (tenant_id, period_start);

-- ---------------------------------------------------------------------------
-- ownership_entities: EIN + status are gone, replaced by v_entity_summary
-- ---------------------------------------------------------------------------
alter table ownership_entities drop column if exists ein;
alter table ownership_entities drop column if exists status;

-- ---------------------------------------------------------------------------
-- v_tenants: surface the lease link/term and the current rent period
-- ---------------------------------------------------------------------------
create view v_tenants
with (security_invoker = true) as
select
  t.*,
  coalesce(nullif(p.nickname, ''), p.name) as property_name,
  l.url as lease_url,
  l.lease_start,
  l.lease_end,
  l.notes as lease_notes,
  rent.amount as monthly_rent,
  rent.cpi_percent as current_cpi_percent,
  rent.period_start as rent_period_start,
  rent.notes as rent_notes
from tenants t
left join properties p on p.id = t.property_id
left join leases l on l.tenant_id = t.id
left join lateral (
  select rs.amount, rs.cpi_percent, rs.period_start, rs.notes
  from rent_schedule rs
  where rs.tenant_id = t.id
    and rs.period_end is null
  order by rs.period_start desc
  limit 1
) rent on true;

-- ---------------------------------------------------------------------------
-- v_entity_summary: the ownership-entity collection read model. Rent/month
-- is the sum of the current-period rents on the entity's active properties;
-- loan payments come straight from loans.monthly_payment (summing the derived
-- loan_payment obligations would double-count); billbacks owed is the
-- outstanding balance owed to this entity.
-- ---------------------------------------------------------------------------
create view v_entity_summary
with (security_invoker = true) as
select
  oe.id,
  oe.organization_id,
  oe.name,
  oe.entity_type,
  oe.notes,
  oe.created_at,
  oe.updated_at,
  coalesce(pc.property_count, 0)::int as property_count,
  coalesce(rent.rent_monthly, 0) as rent_monthly,
  coalesce(loan.loans_monthly, 0) as loans_monthly,
  coalesce(bb.billbacks_owed, 0) as billbacks_owed,
  coalesce(rent.rent_monthly, 0) - coalesce(loan.loans_monthly, 0) as net_monthly
from ownership_entities oe
left join lateral (
  select count(*) as property_count
  from properties p
  where p.ownership_entity_id = oe.id
    and p.status = 'active'
) pc on true
left join lateral (
  select sum(rs.amount) as rent_monthly
  from properties p
  join tenants t on t.property_id = p.id
  join rent_schedule rs on rs.tenant_id = t.id and rs.period_end is null
  where p.ownership_entity_id = oe.id
    and t.status = 'active'
) rent on true
left join lateral (
  select sum(l.monthly_payment) as loans_monthly
  from loans l
  where l.ownership_entity_id = oe.id
    and l.status = 'active'
) loan on true
left join lateral (
  select sum(vb.balance) as billbacks_owed
  from v_billbacks vb
  where vb.to_ownership_entity_id = oe.id
    and vb.is_outstanding
) bb on true;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
drop trigger if exists trg_leases_updated on leases;
drop trigger if exists trg_rent_schedule_updated on rent_schedule;
create trigger trg_leases_updated
  before update on leases for each row execute function set_updated_at();
create trigger trg_rent_schedule_updated
  before update on rent_schedule for each row execute function set_updated_at();
