-- v_cash_needed was missing organization_id, so API queries scoped with
-- .eq('organization_id', orgId) failed. Recreate with the column exposed.
-- (drop first: the column set changes, which CREATE OR REPLACE can't do.)
drop view if exists v_cash_needed;
create view v_cash_needed
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
