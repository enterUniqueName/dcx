-- 000008_nth_weekday.sql
-- Add a "nth weekday of month" scheduling rule so recurrences like
-- "water bill due the 2nd-to-last Wednesday" land on the correct date
-- after each payment (advance_due_date used to blindly add calendar months,
-- which drifts off the rule).
--
--   weekday          0=Sunday .. 6=Saturday
--   nth_occurrence   positive = nth from the start (1 = first),
--                    negative = nth from the end (-1 = last, -2 = 2nd-to-last)

alter table obligations
  add column weekday int check (weekday between 0 and 6),
  add column nth_occurrence int check (nth_occurrence between -5 and 5 and nth_occurrence <> 0);

-- The nth occurrence of a weekday within the month containing p_month.
create or replace function nth_weekday_of_month(p_month date, p_weekday int, p_nth int) returns date
language sql immutable
as $$
  with month_bounds as (
    select
      date_trunc('month', p_month)::date as first_day,
      (date_trunc('month', p_month) + interval '1 month' - interval '1 day')::date as last_day
  )
  select case
    when p_nth > 0 then
      (first_day + ((p_weekday - extract(dow from first_day)::int + 7) % 7) + (p_nth - 1) * 7)::date
    else
      (last_day - ((extract(dow from last_day)::int - p_weekday + 7) % 7) - (abs(p_nth) - 1) * 7)::date
  end
  from month_bounds;
$$;

-- advance_due_date: shift a due date forward by a frequency. A weekday rule
-- wins over due_day; due_day is preserved (clamped to the month length) so
-- day-of-month recurrences don't drift on short months.
create or replace function advance_due_date(
  p_date date,
  p_frequency text,
  p_interval_months int default null,
  p_due_day int default null,
  p_weekday int default null,
  p_nth_occurrence int default null
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
  )
  select case
    when p_weekday is not null and p_nth_occurrence is not null then
      nth_weekday_of_month(b, p_weekday, p_nth_occurrence)
    when p_due_day is not null then
      (date_trunc('month', b)::date
        + least(p_due_day, extract(day from (date_trunc('month', b) + interval '1 month' - interval '1 day'))::int)
        - 1)::date
    else b
  end
  from base;
$$;

-- pay_obligation now carries the scheduling columns through to advance_due_date.
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
begin
  select organization_id, next_due_date, frequency, interval_months, due_day, weekday, nth_occurrence
    into v_org, v_next, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence
  from obligations where id = p_obligation_id
  for update;

  if v_org is null then
    raise exception 'obligation not found';
  end if;
  if not (v_org in (select current_orgs())) then
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
        next_due_date = advance_due_date(next_due_date, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence),
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

-- Point the demo water bill at the rule (2nd-to-last Wednesday). No-op on a
-- fresh database where seed.sql hasn't run yet; fixes the existing row on live.
update obligations
  set weekday = 3, nth_occurrence = -2, due_day = null, next_due_date = '2026-08-19'
  where id = '71000000-0000-4000-8000-000000000028'
    and frequency = 'monthly'
    and category = 'utility';
