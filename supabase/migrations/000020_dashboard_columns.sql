-- 000020_dashboard_columns.sql
-- Add property_address1 to v_obligations and v_billbacks so the dashboard
-- can show "Property Name - Address" in table columns.

-- Drop dependents first.
drop view if exists v_cash_needed;
drop view if exists v_entity_summary;
drop view if exists v_obligations;
drop view if exists v_billbacks;

-- v_billbacks: add p.address1 as property_address1.
create view v_billbacks
with (security_invoker = true) as
select
  b.*,
  f.name as from_entity_name,
  t.name as to_entity_name,
  o.name as obligation_name,
  v.name as vendor_name,
  p.name as property_name,
  p.address1 as property_address1,
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
group by b.id, f.name, t.name, o.name, v.name, p.name, p.address1;

-- v_entity_summary: unchanged, just depends on v_billbacks.
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

-- v_obligations: add p.address1 as property_address1.
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

-- v_cash_needed: unchanged, just depends on v_obligations.
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
