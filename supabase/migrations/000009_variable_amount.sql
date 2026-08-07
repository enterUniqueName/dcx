-- 000009_variable_amount.sql
-- Replace the catch-all 'utility' category with granular 'water'/'electric'
-- (sewer is lumped into water; gas not used), and add a per-obligation
-- variable_amount flag that drives a rolling-average estimated amount.
-- The read model surfaces est_amount = average of the last 3 actual payments
-- when variable_amount is set and at least 3 payments exist, else the
-- configured amount. v_cash_needed uses the estimate so cash forecasts
-- track usage-based bills.

-- Usage-based bills default to the rolling-average estimate.
alter table obligations add column if not exists variable_amount boolean not null default false;

-- Drop the old category constraints FIRST, migrate the data while none is
-- active, then re-add. (Renaming before the constraint swap trips the old
-- list, which has no 'water'; adding the new list first trips existing
-- 'utility' rows.) Idempotent so a partially-applied run can be re-run.
alter table obligations drop constraint if exists obligations_category_check;
alter table vendors drop constraint if exists vendors_category_check;

update obligations set category = 'water' where category = 'utility';
update vendors set category = 'water' where category = 'utility';

alter table obligations add constraint obligations_category_check
  check (category in ('water', 'electric', 'tax', 'insurance', 'loan_payment', 'maintenance', 'service', 'reimbursement', 'other'));

alter table vendors add constraint vendors_category_check
  check (category in ('water', 'electric', 'tax', 'insurance', 'maintenance', 'contractor', 'other'));

update obligations set variable_amount = true where category in ('water', 'electric');

-- ---------------------------------------------------------------------------
-- Read model: v_obligations gains est_amount. Drop first — o.* changes shape
-- as obligations gains columns, which CREATE OR REPLACE can't reconcile.
-- Drop v_cash_needed first: it depends on v_obligations after the first run,
-- which would block re-dropping v_obligations on a re-run.
-- ---------------------------------------------------------------------------
drop view if exists v_cash_needed;
drop view if exists v_obligations;
create view v_obligations
with (security_invoker = true) as
select
  o.*,
  oe.name as ownership_entity_name,
  coalesce(nullif(p.nickname, ''), p.name) as property_name,
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
-- v_cash_needed: base the obligation totals on the estimate.
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
