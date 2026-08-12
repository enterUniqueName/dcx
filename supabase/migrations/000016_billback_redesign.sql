-- 000016_billback_redesign.sql
-- Billbacks redesign:
-- 1. Fix payments.billback_id foreign key to ON DELETE CASCADE (resolves delete constraint bug).
-- 2. Expand billbacks table with check register fields (check_number, vendor_id, property_id, paid_amount, markup_percent, responsibility_type).
-- 3. Make to_ownership_entity_id nullable on billbacks.
-- 4. Create billback_allocations table for multi-party responsible allocations (Tenant, Landlord, Split %/$).
-- 5. Recreate v_billbacks view with vendor, property, and responsible party display summaries.

-- 1. Fix payments FK constraint on billback_id to ON DELETE CASCADE
alter table payments drop constraint if exists payments_billback_id_fkey;
alter table payments
  add constraint payments_billback_id_fkey
  foreign key (billback_id) references billbacks(id) on delete cascade;

-- 2. Make to_ownership_entity_id nullable on billbacks table
alter table billbacks alter column to_ownership_entity_id drop not null;

-- Remove old constraint requiring from <> to if present
alter table billbacks drop constraint if exists billbacks_check;
alter table billbacks add constraint billbacks_check
  check (to_ownership_entity_id is null or from_ownership_entity_id <> to_ownership_entity_id);

-- 3. Add check intake & price adjustment columns to billbacks
alter table billbacks
  add column if not exists check_number text,
  add column if not exists vendor_id uuid references vendors(id) on delete set null,
  add column if not exists property_id uuid references properties(id) on delete set null,
  add column if not exists paid_amount numeric(12, 2),
  add column if not exists markup_percent numeric(5, 2) default 0,
  add column if not exists responsibility_type text default 'tenant'
    check (responsibility_type in ('tenant', 'ownership_entity', 'split'));

-- 4. Create billback_allocations table
create table if not exists billback_allocations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  billback_id uuid not null references billbacks(id) on delete cascade,
  responsible_type text not null check (responsible_type in ('tenant', 'ownership_entity')),
  tenant_id uuid references tenants(id) on delete restrict,
  ownership_entity_id uuid references ownership_entities(id) on delete restrict,
  allocation_type text not null default 'amount' check (allocation_type in ('amount', 'percent')),
  percentage numeric(5, 2),
  amount numeric(12, 2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  check (
    (responsible_type = 'tenant' and tenant_id is not null) or
    (responsible_type = 'ownership_entity' and ownership_entity_id is not null)
  )
);

create index if not exists billback_allocations_billback_idx on billback_allocations(billback_id);
create index if not exists billback_allocations_org_idx on billback_allocations(organization_id);

-- Enable RLS on billback_allocations
alter table billback_allocations enable row level security;

drop policy if exists "Users can view billback_allocations in their orgs" on billback_allocations;
create policy "Users can view billback_allocations in their orgs"
  on billback_allocations for select
  using (organization_id in (select current_orgs()));

drop policy if exists "Users can insert billback_allocations in their orgs" on billback_allocations;
create policy "Users can insert billback_allocations in their orgs"
  on billback_allocations for insert
  with check (can_write_org(organization_id));

drop policy if exists "Users can update billback_allocations in their orgs" on billback_allocations;
create policy "Users can update billback_allocations in their orgs"
  on billback_allocations for update
  using (can_write_org(organization_id));

drop policy if exists "Users can delete billback_allocations in their orgs" on billback_allocations;
create policy "Users can delete billback_allocations in their orgs"
  on billback_allocations for delete
  using (can_write_org(organization_id));

-- 5. Recreate v_billbacks view. New columns can't be added with CREATE OR
-- REPLACE, so drop first; v_entity_summary depends on v_billbacks and is
-- recreated right after.
drop view if exists v_entity_summary;
drop view if exists v_billbacks;

create view v_billbacks
with (security_invoker = true) as
select
  b.*,
  f.name as from_entity_name,
  t.name as to_entity_name,
  o.name as obligation_name,
  v.name as vendor_name,
  p.name as property_name,
  coalesce(
    (
      select string_agg(
        case
          when ba.responsible_type = 'tenant' then tn.name || ' (Tenant)'
          when ba.responsible_type = 'ownership_entity' then oe.name || ' (Landlord)'
        end,
        ', '
      )
      from billback_allocations ba
      left join tenants tn on tn.id = ba.tenant_id
      left join ownership_entities oe on oe.id = ba.ownership_entity_id
      where ba.billback_id = b.id
    ),
    t.name,
    'Unassigned'
  ) as responsible_party_display,
  coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) as amount_paid,
  b.amount - coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) as balance,
  (b.amount - coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) > 0)
    and b.status <> 'waived' as is_outstanding
from billbacks b
left join ownership_entities f on f.id = b.from_ownership_entity_id
left join ownership_entities t on t.id = b.to_ownership_entity_id
left join obligations o on o.id = b.obligation_id
left join vendors v on v.id = b.vendor_id
left join properties p on p.id = b.property_id
left join payments pay on pay.billback_id = b.id
group by b.id, f.name, t.name, o.name, v.name, p.name;

-- v_entity_summary: restored from 000010 (it depends on v_billbacks).
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
