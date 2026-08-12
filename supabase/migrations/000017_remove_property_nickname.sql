-- 000017_remove_property_nickname.sql
-- Drop properties.nickname. The nickname was a short display label layered on
-- top of the address-as-name (000006); it duplicated name and confused the UI
-- (everywhere it appeared we fell back to name anyway). This migration removes
-- the column and reroutes every read model that preferred nickname to plain
-- name.
--
-- Views are dropped before the column because they reference
-- properties.nickname directly (CREATE OR REPLACE can't remove a referenced
-- column), then recreated with `name` in its place. v_cash_needed depends on
-- v_obligations, so it must come down first. loans.nickname (000012) is
-- untouched.

-- ---------------------------------------------------------------------------
-- Drop the views that reference properties.nickname, dependents first.
-- ---------------------------------------------------------------------------
drop view if exists v_cash_needed;
drop view if exists v_obligations;
drop view if exists v_loans;
drop view if exists v_tenants;
drop view if exists v_documents;
drop view if exists v_properties;

alter table properties drop column if exists nickname;

-- ---------------------------------------------------------------------------
-- Recreate v_obligations with property_name = name.
-- ---------------------------------------------------------------------------
create view v_obligations
with (security_invoker = true) as
select
  o.*,
  oe.name as ownership_entity_name,
  p.name as property_name,
  v.name as vendor_name,
  v.category as vendor_category,
  l.lender as loan_name,
  t.name as tenant_name,
  (o.status = 'open' and o.next_due_date < current_date) as is_overdue,
  est.est_amount
from obligations o
left join ownership_entities oe on oe.id = o.ownership_entity_id
left join properties p on p.id = o.property_id
left join vendors v on v.id = o.vendor_id
left join loans l on l.id = o.loan_id
left join tenants t on t.id = o.tenant_id
left join lateral (
  select case
    when o.variable_amount and cnt >= 3 then round(avg_amount, 2)
    else o.amount
  end as est_amount
  from (
    select count(*) as cnt, avg(amount) as avg_amount
    from (
      select pay.amount
      from payments pay
      where pay.obligation_id = o.id
      order by pay.paid_date desc, pay.created_at desc
      limit 3
    ) recent
  ) agg
) est on true;

-- ---------------------------------------------------------------------------
-- Recreate v_cash_needed (unchanged, but v_obligations had to come down).
-- ---------------------------------------------------------------------------
create view v_cash_needed
with (security_invoker = true) as
with obligation_totals as (
  select
    ownership_entity_id,
    date_trunc('month', next_due_date)::date as month,
    sum(est_amount) as obligations_amount
  from v_obligations
  where status = 'open'
    and next_due_date >= date_trunc('month', current_date)::date
    and next_due_date < date_trunc('month', current_date)::date + interval '6 months'
  group by ownership_entity_id, date_trunc('month', next_due_date)::date
),
billback_totals as (
  select
    to_ownership_entity_id as ownership_entity_id,
    date_trunc('month', coalesce(due_date, issued_date))::date as month,
    sum(b.amount - coalesce((select sum(p.amount) from payments p where p.billback_id = b.id), 0)) as billbacks_amount
  from billbacks b
  where b.status <> 'waived'
  group by to_ownership_entity_id, date_trunc('month', coalesce(due_date, issued_date))::date
)
select
  oe.organization_id,
  oe.id as ownership_entity_id,
  oe.name as ownership_entity_name,
  coalesce(o.month, bb.month) as month,
  coalesce(o.obligations_amount, 0) as obligations_amount,
  coalesce(bb.billbacks_amount, 0) as billbacks_amount,
  coalesce(o.obligations_amount, 0) + coalesce(bb.billbacks_amount, 0) as total
from ownership_entities oe
left join obligation_totals o on o.ownership_entity_id = oe.id
left join billback_totals bb on bb.ownership_entity_id = oe.id
where o.month is not null or bb.month is not null;

-- ---------------------------------------------------------------------------
-- Recreate v_loans with property_name = name.
-- ---------------------------------------------------------------------------
create view v_loans
with (security_invoker = true) as
select
  l.*,
  oe.name as ownership_entity_name,
  p.name as property_name
from loans l
left join ownership_entities oe on oe.id = l.ownership_entity_id
left join properties p on p.id = l.property_id;

-- ---------------------------------------------------------------------------
-- Recreate v_tenants with property_name = name.
-- ---------------------------------------------------------------------------
create view v_tenants
with (security_invoker = true) as
select
  t.*,
  p.name as property_name,
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
-- Recreate v_documents with entity_name = property name.
-- ---------------------------------------------------------------------------
create view v_documents
with (security_invoker = true) as
select
  d.*,
  coalesce(
    o.name,
    pr.name,
    oe.name,
    l.lender,
    t.name,
    v.name,
    b.description
  ) as entity_name
from documents d
left join obligations o on d.entity_type = 'obligation' and o.id = d.entity_id
left join properties pr on d.entity_type = 'property' and pr.id = d.entity_id
left join ownership_entities oe on d.entity_type = 'ownership_entity' and oe.id = d.entity_id
left join loans l on d.entity_type = 'loan' and l.id = d.entity_id
left join tenants t on d.entity_type = 'tenant' and t.id = d.entity_id
left join vendors v on d.entity_type = 'vendor' and v.id = d.entity_id
left join billbacks b on d.entity_type = 'billback' and b.id = d.entity_id;

-- ---------------------------------------------------------------------------
-- Recreate v_properties with property_name = name.
-- ---------------------------------------------------------------------------
create view v_properties
with (security_invoker = true) as
select
  pr.*,
  pr.name as property_name,
  oe.name as ownership_entity_name,
  tax.tax_next_due_date,
  tax.tax_next_amount
from properties pr
left join ownership_entities oe on oe.id = pr.ownership_entity_id
left join lateral (
  select ob.next_due_date as tax_next_due_date,
         ob.amount as tax_next_amount
  from obligations ob
  where ob.property_id = pr.id
    and ob.category = 'tax'
    and ob.status = 'open'
  order by ob.next_due_date
  limit 1
) tax on true;
