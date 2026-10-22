-- A concrete bill's stored amount is authoritative. Variable templates use
-- the rolling estimate when creating bills, but a later bill edit must not be
-- masked by recalculating that estimate in the read view.
drop view if exists v_cash_needed;
drop view if exists v_obligations;

create view v_obligations
with (security_invoker = true) as
select
  o.*,
  oe.name as ownership_entity_name,
  p.name as property_name,
  p.address1 as property_address1,
  v.name as vendor_name,
  v.category as vendor_category,
  l.lender as loan_name,
  l.loan_number as loan_account,
  t.name as tenant_name,
  (o.kind = 'bill' and o.status = 'open' and o.next_due_date < current_date) as is_overdue,
  case
    when o.kind = 'template' and o.variable_amount
      then coalesce(series_est_amount(o.id), o.amount)
    else o.amount
  end as est_amount,
  coalesce(o.portal_url, v.website, l.payment_url) as payment_url
from obligations o
left join ownership_entities oe on oe.id = o.ownership_entity_id
left join properties p on p.id = o.property_id
left join vendors v on v.id = o.vendor_id
left join loans l on l.id = o.loan_id
left join tenants t on t.id = o.tenant_id;

create view v_cash_needed
with (security_invoker = true) as
with obligation_totals as (
  select
    ownership_entity_id,
    date_trunc('month', next_due_date)::date as month,
    sum(est_amount) as obligations_amount
  from v_obligations
  where kind = 'bill'
    and status = 'open'
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
),
combined as (
  select ownership_entity_id, month, obligations_amount, 0 as billbacks_amount
  from obligation_totals
  union all
  select ownership_entity_id, month, 0, billbacks_amount
  from billback_totals
)
select
  oe.organization_id,
  oe.id as ownership_entity_id,
  oe.name as ownership_entity_name,
  c.month,
  sum(c.obligations_amount) as obligations_amount,
  sum(c.billbacks_amount) as billbacks_amount,
  sum(c.obligations_amount + c.billbacks_amount) as total
from ownership_entities oe
join combined c on c.ownership_entity_id = oe.id
group by oe.organization_id, oe.id, oe.name, c.month;
