-- Add payment_url to loans so each lender portal can be stored once.
ALTER TABLE loans ADD COLUMN payment_url text;

-- v_cash_needed depends on v_obligations, so bring it down first and
-- recreate it after (unchanged from 000023).
drop view if exists v_cash_needed;

-- Recreate v_obligations with a computed payment_url that coalesces from:
--   1. obligation.portal_url (manual override per bill)
--   2. vendors.website (set once per vendor, e.g. CityLink, AEP)
--   3. loans.payment_url (set once per loan, e.g. Pinnacle, Freedom First)
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
  t.name as tenant_name,
  (o.kind = 'bill' and o.status = 'open' and o.next_due_date < current_date) as is_overdue,
  est.est_amount,
  coalesce(o.portal_url, v.website, l.payment_url) as payment_url
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

-- Recreate v_cash_needed (unchanged fix from 000023: entity+month dedup).
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
