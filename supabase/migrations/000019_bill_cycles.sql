-- 000019_bill_cycles.sql
-- Split recurring templates from concrete bills. Each bill becomes its own
-- obligations row (kind='bill', series_id -> its template), generated on a
-- time-based schedule so unpaid bills stack up as overdue rows while new bills
-- keep being created. Payments are MERGED into bill rows (paid_amount /
-- paid_date / method / reference / funding_entity_id); the payments table
-- stays for billbacks.
--
--   * obligations.kind ('template' | 'bill') + obligations.series_id
--   * per-bill payment fields on obligations
--   * series_est_amount(): rolling estimate from the last 3 paid bills
--   * generate_bills(): materialize missing bills per template (time-based)
--   * pay_bill(): mark a bill paid (replaces pay_obligation for the new flow)
--   * views recreated so overdue / cash-needed / property-tax read bills only

-- ---------------------------------------------------------------------------
-- Schema: kind + series link + merged-payment fields.
-- ---------------------------------------------------------------------------
alter table obligations add column if not exists kind text not null default 'template';
alter table obligations add column if not exists series_id uuid references obligations(id) on delete cascade;
alter table obligations add column if not exists paid_amount numeric(12, 2);
alter table obligations add column if not exists paid_date date;
alter table obligations add column if not exists method text;
alter table obligations add column if not exists reference text;
alter table obligations add column if not exists funding_entity_id uuid references ownership_entities(id) on delete set null;
alter table obligations drop constraint if exists obligations_kind_check;
alter table obligations add constraint obligations_kind_check check (kind in ('template', 'bill'));

create index if not exists obligations_series_id_idx on obligations (series_id);
-- One bill per series per due date (the generator's idempotency guard).
create unique index if not exists obligations_series_due_uq
  on obligations (series_id, next_due_date) where series_id is not null;

-- ---------------------------------------------------------------------------
-- Backfill: existing rows are recurrence templates. Past one-time rows are
-- historical one-off bills (no series).
-- ---------------------------------------------------------------------------
update obligations set kind = 'bill' where frequency = 'one_time';

-- ---------------------------------------------------------------------------
-- series_est_amount: rolling estimate for a variable series = average of the
-- last 3 PAID bills' amounts (the old estimate averaged payments; bills are
-- now the records). Falls back via coalesce() to the template amount.
-- ---------------------------------------------------------------------------
create or replace function series_est_amount(p_series uuid)
returns numeric
language sql stable
as $$
  select round(avg(amount), 2)
  from (
    select amount
    from obligations
    where series_id = p_series
      and status = 'paid'
      and amount is not null
    order by next_due_date desc
    limit 3
  ) recent;
$$;

-- ---------------------------------------------------------------------------
-- generate_bills: for every active template (in the caller's org unless
-- p_organization_id given), materialize one bill per due date from the last
-- generated due date forward until p_target_date (default: today + 180 days,
-- covering the 6-month cash forecast). Time-based, so unpaid bills accumulate
-- as separate open rows instead of one row drifting late. Idempotent via the
-- (series_id, next_due_date) unique index.
--
-- The seed / SQL editor call this as postgres with no auth.uid(); in that
-- trusted admin context the org membership checks are skipped. Authenticated
-- callers are restricted to orgs they can write.
-- ---------------------------------------------------------------------------
create or replace function generate_bills(
  p_organization_id uuid default null,
  p_target_date date default null
) returns int
language plpgsql security definer
as $$
declare
  v_org uuid := p_organization_id;
  v_target date := coalesce(p_target_date, current_date + interval '180 days');
  v_created int := 0;
  v_admin boolean;
  t record;
  v_last date;
  v_next date;
  v_amount numeric(12, 2);
begin
  if auth.uid() is null and current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'not authenticated';
  end if;
  v_admin := (auth.uid() is null);

  if v_org is null then
    select organization_id into v_org from current_orgs() limit 1;
  end if;
  if v_org is null then
    return 0;
  end if;
  if not v_admin and not can_write_org(v_org) then
    raise exception 'permission denied';
  end if;

  for t in
    select o.*
    from obligations o
    where o.series_id is null
      and o.kind = 'template'
      and o.status = 'open'
      and o.frequency <> 'one_time'
      and o.next_due_date is not null
      and o.organization_id = v_org
    order by o.id
  loop
    select max(next_due_date) into v_last
    from obligations where series_id = t.id;
    if v_last is null then
      v_last := t.next_due_date;
      if v_last > v_target then
        continue;
      end if;
      v_amount := case when t.variable_amount
        then coalesce(series_est_amount(t.id), t.amount)
        else t.amount end;
      insert into obligations (
        organization_id, series_id, kind, ownership_entity_id, property_id,
        vendor_id, tenant_id, loan_id, name, description, category, amount,
        variable_amount, frequency, interval_months, due_day, weekday,
        nth_occurrence, installment_months, interval_days, next_due_date,
        status, received, portal_url
      ) values (
        v_org, t.id, 'bill', t.ownership_entity_id, t.property_id,
        t.vendor_id, t.tenant_id, t.loan_id, t.name, t.description, t.category,
        v_amount, t.variable_amount, t.frequency, t.interval_months, t.due_day,
        t.weekday, t.nth_occurrence, t.installment_months, t.interval_days,
        v_last, 'open', false, t.portal_url
      )
      on conflict (series_id, next_due_date) where series_id is not null do nothing;
      if found then
        v_created := v_created + 1;
      end if;
    elsif v_last > v_target then
      continue;
    end if;

    loop
      v_next := advance_due_date(
        v_last, t.frequency, t.interval_months, t.due_day,
        t.weekday, t.nth_occurrence, t.installment_months, t.interval_days
      );
      exit when v_next is null or v_next <= v_last or v_next > v_target;

      v_amount := case when t.variable_amount
        then coalesce(series_est_amount(t.id), t.amount)
        else t.amount end;

      insert into obligations (
        organization_id, series_id, kind, ownership_entity_id, property_id,
        vendor_id, tenant_id, loan_id, name, description, category, amount,
        variable_amount, frequency, interval_months, due_day, weekday,
        nth_occurrence, installment_months, interval_days, next_due_date,
        status, received, portal_url
      ) values (
        v_org, t.id, 'bill', t.ownership_entity_id, t.property_id,
        t.vendor_id, t.tenant_id, t.loan_id, t.name, t.description, t.category,
        v_amount, t.variable_amount, t.frequency, t.interval_months, t.due_day,
        t.weekday, t.nth_occurrence, t.installment_months, t.interval_days,
        v_next, 'open', false, t.portal_url
      )
      on conflict (series_id, next_due_date) where series_id is not null do nothing;

      if found then
        v_created := v_created + 1;
      end if;
      v_last := v_next;
    end loop;
  end loop;

  return v_created;
end;
$$;

-- ---------------------------------------------------------------------------
-- pay_bill: record a payment against a single open bill. Supports partial
-- payments (bill stays open until paid_amount >= amount) and marks the bill
-- paid with the funding entity / method / reference recorded on the row —
-- the bill IS the payment history now. (Keeps the can_write_org hardening.)
-- ---------------------------------------------------------------------------
create or replace function pay_bill(
  p_bill_id uuid,
  p_amount numeric(12, 2),
  p_paid_date date,
  p_funding_entity_id uuid default null,
  p_method text default null,
  p_reference text default null,
  p_notes text default null
) returns jsonb
language plpgsql security definer
as $$
declare
  v_org uuid;
  v_entity_org uuid;
  v_amount numeric(12, 2);
  v_paid numeric(12, 2);
  v_new_paid numeric(12, 2);
  v_status text;
begin
  select organization_id, amount, coalesce(paid_amount, 0), status
    into v_org, v_amount, v_paid, v_status
  from obligations where id = p_bill_id
  for update;

  if v_org is null then
    raise exception 'bill not found';
  end if;
  if v_status <> 'open' then
    raise exception 'bill is not open';
  end if;
  if not can_write_org(v_org) then
    raise exception 'permission denied';
  end if;

  if p_funding_entity_id is not null then
    select organization_id into v_entity_org
    from ownership_entities where id = p_funding_entity_id;
    if v_entity_org is null or v_entity_org <> v_org then
      raise exception 'funding entity does not belong to the organization';
    end if;
  end if;

  v_new_paid := v_paid + p_amount;
  v_status := case when v_new_paid >= v_amount then 'paid' else 'open' end;

  update obligations
    set status = v_status,
        paid_amount = v_new_paid,
        paid_date = coalesce(p_paid_date, paid_date),
        method = coalesce(p_method, method),
        reference = coalesce(p_reference, reference),
        funding_entity_id = coalesce(p_funding_entity_id, funding_entity_id),
        notes = case
          when p_notes is not null and notes is null then p_notes
          when p_notes is not null then notes || E'\n' || p_notes
          else notes end,
        updated_at = now()
  where id = p_bill_id;

  return jsonb_build_object(
    'bill_id', p_bill_id,
    'status', v_status,
    'paid_amount', v_new_paid,
    'remaining', greatest(v_amount - v_new_paid, 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Read model: overdue / cash forecasts / property tax now read BILLS only
-- (templates must not show as due or count toward cash needed).
-- ---------------------------------------------------------------------------
drop view if exists v_cash_needed;
drop view if exists v_obligations;

-- v_payments / v_cross_entity_payments: the global payments log now unions
-- PAID BILLS (payment fields live on the bill row) with billback payments
-- (still rows in the payments table). Column shape is preserved for the API.
drop view if exists v_cross_entity_payments;
drop view if exists v_payments;

create view v_payments
with (security_invoker = true) as
select
  src.id,
  src.organization_id,
  src.obligation_id,
  src.ownership_entity_id,
  src.billback_id,
  src.amount,
  src.paid_date,
  src.method,
  src.reference,
  src.notes,
  src.created_by,
  src.created_at,
  src.updated_at,
  o.name as obligation_name,
  o.category as obligation_category,
  o.ownership_entity_id as obligation_entity_id,
  oe.name as funding_entity_name,
  oe2.name as obligation_entity_name,
  b.to_ownership_entity_id as billback_to_entity_id,
  (src.ownership_entity_id is not null
    and o.ownership_entity_id is not null
    and src.ownership_entity_id is distinct from o.ownership_entity_id) as is_cross_entity
from (
  -- Paid bills carry their own payment record.
  select
    ob.id,
    ob.organization_id,
    ob.id as obligation_id,
    ob.funding_entity_id as ownership_entity_id,
    null::uuid as billback_id,
    ob.paid_amount as amount,
    ob.paid_date,
    ob.method,
    ob.reference,
    ob.notes,
    null::uuid as created_by,
    ob.created_at,
    ob.updated_at
  from obligations ob
  where ob.kind = 'bill' and ob.status = 'paid' and ob.paid_date is not null
  union all
  -- Billback payments stay rows in the payments table.
  select
    pay.id,
    pay.organization_id,
    pay.obligation_id,
    pay.ownership_entity_id,
    pay.billback_id,
    pay.amount,
    pay.paid_date,
    pay.method,
    pay.reference,
    pay.notes,
    pay.created_by,
    pay.created_at,
    pay.updated_at
  from payments pay
  where pay.billback_id is not null
) src
left join obligations o on o.id = src.obligation_id
left join ownership_entities oe on oe.id = src.ownership_entity_id
left join ownership_entities oe2 on oe2.id = o.ownership_entity_id
left join billbacks b on b.id = src.billback_id;

-- Cross-entity payments: entity X funded a payment whose obligation belongs to
-- entity Y. Answers "what did PLB pay on behalf of another entity?"
create view v_cross_entity_payments
with (security_invoker = true) as
select
  src.id,
  src.organization_id,
  src.obligation_id,
  src.ownership_entity_id,
  src.billback_id,
  src.amount,
  src.paid_date,
  src.method,
  src.reference,
  src.notes,
  src.created_by,
  src.created_at,
  src.updated_at,
  o.ownership_entity_id as obligation_entity_id,
  oe.name as funding_entity_name,
  oe2.name as obligation_entity_name
from (
  select
    ob.id,
    ob.organization_id,
    ob.id as obligation_id,
    ob.funding_entity_id as ownership_entity_id,
    null::uuid as billback_id,
    ob.paid_amount as amount,
    ob.paid_date,
    ob.method,
    ob.reference,
    ob.notes,
    null::uuid as created_by,
    ob.created_at,
    ob.updated_at
  from obligations ob
  where ob.kind = 'bill' and ob.status = 'paid' and ob.funding_entity_id is not null
  union all
  select
    pay.id,
    pay.organization_id,
    pay.obligation_id,
    pay.ownership_entity_id,
    pay.billback_id,
    pay.amount,
    pay.paid_date,
    pay.method,
    pay.reference,
    pay.notes,
    pay.created_by,
    pay.created_at,
    pay.updated_at
  from payments pay
  where pay.billback_id is null and pay.obligation_id is not null
) src
join obligations o on o.id = src.obligation_id
join ownership_entities oe on oe.id = src.ownership_entity_id
join ownership_entities oe2 on oe2.id = o.ownership_entity_id
where src.ownership_entity_id is distinct from o.ownership_entity_id;

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

-- v_properties: the next tax installment now lives on the generated tax BILL.
drop view if exists v_properties;
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
    and ob.kind = 'bill'
    and ob.category = 'tax'
    and ob.status = 'open'
  order by ob.next_due_date
  limit 1
) tax on true;
