-- Variable bills store the actual payment on obligations.paid_amount. The
-- previous estimator averaged the generated amount, which could remain zero.
-- Include legacy payment rows so estimates retain pre-bill-cycle history.
create or replace function series_est_amount(p_series uuid)
returns numeric
language sql stable
set search_path = public, pg_temp
as $$
  select round(avg(actual_amount), 2)
  from (
    select actual_amount
    from (
      select
        b.paid_amount as actual_amount,
        coalesce(b.paid_date, b.next_due_date) as paid_on,
        b.updated_at as recorded_at
      from obligations b
      where b.series_id = p_series
        and b.status = 'paid'
        and b.paid_amount is not null

      union all

      select
        p.amount as actual_amount,
        p.paid_date as paid_on,
        p.created_at as recorded_at
      from payments p
      where p.obligation_id = p_series
        and p.billback_id is null
        and p.amount is not null
    ) history
    order by paid_on desc, recorded_at desc
    limit 3
  ) recent;
$$;

-- Correct already-generated open variable bills that still have a zero
-- placeholder. Nonzero bills may contain a known invoice amount and are left
-- untouched.
update obligations b
set amount = series_est_amount(b.series_id),
    updated_at = now()
where b.kind = 'bill'
  and b.status = 'open'
  and b.variable_amount
  and b.series_id is not null
  and b.amount = 0
  and series_est_amount(b.series_id) is not null;

-- v_cash_needed depends on v_obligations, so recreate it after replacing the
-- stale payment-table estimate with the series-aware estimate.
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
    when not o.variable_amount then o.amount
    when o.kind = 'template' then coalesce(series_est_amount(o.id), o.amount)
    when o.series_id is not null then coalesce(series_est_amount(o.series_id), o.amount)
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
