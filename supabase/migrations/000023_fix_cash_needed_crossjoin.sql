-- Fix v_cash_needed: the old LEFT JOINs on ownership_entity_id alone produced
-- duplicate rows when an entity had both obligations and billbacks (cross-join).
-- Replace with a UNION ALL + GROUP BY so each entity gets exactly one row per month.

drop view if exists v_cash_needed;

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
