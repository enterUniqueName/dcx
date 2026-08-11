-- 000015_tax_installments.sql
-- Lynchburg, VA real estate taxes are billed in four quarterly installments
-- (due Nov 15, Jan 15, Mar 15, May 15), not one annual bill on Dec 5. This
-- migration:
--   * stores the annual levy on the property (properties.annual_tax),
--   * adds a quarterly-installment schedule rule to obligations
--     (obligations.installment_months) and teaches advance_due_date /
--     pay_obligation to roll to the next installment date,
--   * converts the seeded tax obligations from annual/Dec-5 to quarterly
--     installments (amount = annual / 4),
--   * surfaces annual tax + next installment on v_properties.

-- ---------------------------------------------------------------------------
-- properties.annual_tax: the county's annual levy for the property.
-- Backfilled from the old free-text property notes, then the notes cleaned.
-- ---------------------------------------------------------------------------
alter table properties add column if not exists annual_tax numeric(12, 2);

update properties
set annual_tax = nullif(substring(notes from 'Annual real estate tax\s+([0-9.]+)')::numeric, 0)
where annual_tax is null
  and notes ~ 'Annual real estate tax\s+[0-9.]+';

update properties
set notes = null
where notes ~ '^Annual real estate tax\s+[0-9.]+\s+\(from property import\)$';

-- ---------------------------------------------------------------------------
-- obligations.installment_months: when set, the obligation recurs on those
-- months' due day (e.g. {1,3,5,11} + due_day 15 = Lynchburg's schedule).
-- ---------------------------------------------------------------------------
alter table obligations add column if not exists installment_months int[];

-- ---------------------------------------------------------------------------
-- advance_due_date: a new scheduling branch — the next installment date after
-- p_date (the earliest of the installment months' due day in this or next
-- year). Handles late payments correctly: pay the Nov 15 bill late, and the
-- next due date is still Jan 15, not "+3 months".
-- (Drops the superseded overloads so 3-/6-arg calls don't become ambiguous.)
-- ---------------------------------------------------------------------------
drop function if exists advance_due_date(date, text, int);
drop function if exists advance_due_date(date, text, int, int, int, int);

create or replace function advance_due_date(
  p_date date,
  p_frequency text,
  p_interval_months int default null,
  p_due_day int default null,
  p_weekday int default null,
  p_nth_occurrence int default null,
  p_installment_months int[] default null
) returns date
language sql immutable
as $$
  with base as (
    select case
      when p_frequency = 'monthly'     then (p_date + interval '1 month')::date
      when p_frequency = 'quarterly'   then (p_date + interval '3 months')::date
      when p_frequency = 'semi_annual' then (p_date + interval '6 months')::date
      when p_frequency = 'annual'      then (p_date + interval '1 year')::date
      when p_frequency = 'custom'      then (p_date + (coalesce(p_interval_months, 1) * interval '1 month'))::date
      else p_date
    end as b
  ),
  next_installment as (
    select make_date(y, m, least(coalesce(p_due_day, 15), 28)) as d
    from unnest(p_installment_months) as m,
         generate_series(extract(year from p_date)::int, extract(year from p_date)::int + 1) as y
  )
  select case
    when p_weekday is not null and p_nth_occurrence is not null then
      nth_weekday_of_month(b, p_weekday, p_nth_occurrence)
    when p_installment_months is not null then
      (select min(d) from next_installment where d > p_date)
    when p_due_day is not null then
      (date_trunc('month', b)::date
        + least(p_due_day, extract(day from (date_trunc('month', b) + interval '1 month' - interval '1 day'))::int)
        - 1)::date
    else b
  end
  from base;
$$;

-- ---------------------------------------------------------------------------
-- pay_obligation: carry installment_months through to advance_due_date.
-- (Keeps the can_write_org hardening from 000014.)
-- ---------------------------------------------------------------------------
create or replace function pay_obligation(
  p_obligation_id uuid,
  p_amount numeric(12, 2),
  p_paid_date date,
  p_ownership_entity_id uuid default null,
  p_method text default null,
  p_reference text default null,
  p_notes text default null
) returns jsonb
language plpgsql security definer
as $$
declare
  v_org uuid;
  v_entity_org uuid;
  v_next date;
  v_freq text;
  v_interval int;
  v_due_day int;
  v_weekday int;
  v_nth_occurrence int;
  v_installment_months int[];
begin
  select organization_id, next_due_date, frequency, interval_months, due_day, weekday, nth_occurrence, installment_months
    into v_org, v_next, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence, v_installment_months
  from obligations where id = p_obligation_id
  for update;

  if v_org is null then
    raise exception 'obligation not found';
  end if;
  if not can_write_org(v_org) then
    raise exception 'permission denied';
  end if;

  if p_ownership_entity_id is not null then
    select organization_id into v_entity_org
    from ownership_entities where id = p_ownership_entity_id;
    if v_entity_org is null or v_entity_org <> v_org then
      raise exception 'funding entity does not belong to the organization';
    end if;
  end if;

  insert into payments (
    organization_id, obligation_id, ownership_entity_id,
    amount, paid_date, method, reference, notes, created_by
  ) values (
    v_org, p_obligation_id, p_ownership_entity_id,
    p_amount, p_paid_date, p_method, p_reference, p_notes, auth.uid()
  );

  update obligations
    set status = case when frequency = 'one_time' then 'paid' else 'open' end,
        next_due_date = advance_due_date(next_due_date, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence, v_installment_months),
        received = false,
        received_date = null,
        updated_at = now()
  where id = p_obligation_id;

  return jsonb_build_object(
    'obligation_id', p_obligation_id,
    'paid_date', p_paid_date,
    'next_due_date', (select next_due_date from obligations where id = p_obligation_id)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Convert seeded tax obligations to the quarterly schedule. Guarded on
-- installment_months so a re-run (idempotency) does not halve the amount
-- again. amount = annual / 4; next_due_date = next installment after today.
-- ---------------------------------------------------------------------------
update obligations
set frequency = 'quarterly',
    installment_months = '{1,3,5,11}',
    due_day = 15,
    weekday = null,
    nth_occurrence = null,
    amount = round(amount / 4, 2),
    next_due_date = advance_due_date(current_date, 'quarterly', null, 15, null, null, '{1,3,5,11}')
where category = 'tax'
  and installment_months is null;

-- ---------------------------------------------------------------------------
-- v_properties: expose annual_tax + the next tax installment. Recreate (pr.*
-- froze its column list at 000011; a new base column can't be added in place).
-- ---------------------------------------------------------------------------
drop view if exists v_properties;
create view v_properties
with (security_invoker = true) as
select
  pr.*,
  coalesce(nullif(pr.nickname, ''), pr.name) as property_name,
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
