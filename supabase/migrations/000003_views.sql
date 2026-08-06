-- 000003_views.sql
-- Read models. security_invoker views: RLS on the underlying tables keeps
-- applying, so a view never leaks rows across organizations.

create or replace view v_obligations
with (security_invoker = true) as
select
  o.*,
  oe.name as ownership_entity_name,
  p.name as property_name,
  v.name as vendor_name,
  v.category as vendor_category,
  l.lender as loan_name,
  t.name as tenant_name,
  (o.status = 'open' and o.next_due_date < current_date) as is_overdue
from obligations o
left join ownership_entities oe on oe.id = o.ownership_entity_id
left join properties p on p.id = o.property_id
left join vendors v on v.id = o.vendor_id
left join loans l on l.id = o.loan_id
left join tenants t on t.id = o.tenant_id;

create or replace view v_payments
with (security_invoker = true) as
select
  pay.*,
  o.name as obligation_name,
  o.category as obligation_category,
  o.ownership_entity_id as obligation_entity_id,
  oe.name as funding_entity_name,
  oe2.name as obligation_entity_name,
  b.to_ownership_entity_id as billback_to_entity_id,
  (pay.ownership_entity_id is not null
    and o.ownership_entity_id is not null
    and pay.ownership_entity_id is distinct from o.ownership_entity_id) as is_cross_entity
from payments pay
left join obligations o on o.id = pay.obligation_id
left join ownership_entities oe on oe.id = pay.ownership_entity_id
left join ownership_entities oe2 on oe2.id = o.ownership_entity_id
left join billbacks b on b.id = pay.billback_id;

create or replace view v_billbacks
with (security_invoker = true) as
select
  b.*,
  f.name as from_entity_name,
  t.name as to_entity_name,
  o.name as obligation_name,
  coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) as amount_paid,
  b.amount - coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) as balance,
  (b.amount - coalesce(sum(pay.amount) filter (where pay.billback_id = b.id), 0) > 0)
    and b.status <> 'waived' as is_outstanding
from billbacks b
left join ownership_entities f on f.id = b.from_ownership_entity_id
left join ownership_entities t on t.id = b.to_ownership_entity_id
left join obligations o on o.id = b.obligation_id
left join payments pay on pay.billback_id = b.id
group by b.id, f.name, t.name, o.name;

create or replace view v_org_members
with (security_invoker = true) as
select
  m.organization_id,
  m.user_id,
  m.role,
  p.display_name
from org_members m
left join profiles p on p.id = m.user_id;

create or replace view v_loans
with (security_invoker = true) as
select
  l.*,
  oe.name as ownership_entity_name,
  p.name as property_name
from loans l
left join ownership_entities oe on oe.id = l.ownership_entity_id
left join properties p on p.id = l.property_id;

create or replace view v_tenants
with (security_invoker = true) as
select
  t.*,
  p.name as property_name
from tenants t
left join properties p on p.id = t.property_id;

create or replace view v_properties
with (security_invoker = true) as
select
  pr.*,
  oe.name as ownership_entity_name
from properties pr
left join ownership_entities oe on oe.id = pr.ownership_entity_id;

create or replace view v_documents
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
-- Dashboard/report aggregates (returned through the API as named queries)
-- ---------------------------------------------------------------------------

-- Cash needed per ownership entity for a given month: open obligations due in
-- the month plus outstanding billbacks where the entity is the debtor.
create or replace view v_cash_needed
with (security_invoker = true) as
with obligation_totals as (
  select
    ownership_entity_id,
    date_trunc('month', next_due_date)::date as month,
    sum(amount) as obligations_amount
  from obligations
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

-- Cross-entity payments: entity X funded a payment whose obligation belongs to
-- entity Y. Answers "what did PLB pay on behalf of another entity?"
create or replace view v_cross_entity_payments
with (security_invoker = true) as
select
  pay.*,
  o.ownership_entity_id as obligation_entity_id,
  oe.name as funding_entity_name,
  oe2.name as obligation_entity_name
from payments pay
join obligations o on o.id = pay.obligation_id
join ownership_entities oe on oe.id = pay.ownership_entity_id
join ownership_entities oe2 on oe2.id = o.ownership_entity_id
where pay.ownership_entity_id is distinct from o.ownership_entity_id;
