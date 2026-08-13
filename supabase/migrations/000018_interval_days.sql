-- 000018_interval_days.sql
-- Real utility bills don't fall on a fixed day of the month: electric bills
-- arrive 28-33 days after the previous bill's due date, so a fixed due_day
-- (or calendar-month advancement) drifts off the real schedule. This adds an
-- interval_days scheduling rule:
--   * obligations.interval_days — when set, the next due date is exactly that
--     many days after the previous due date, regardless of calendar-month
--     lengths. It wins over the due_day / weekday / installment rules.
--   * advance_due_date / pay_obligation learn to honor it,
--   * existing electric obligations are converted to interval_days = 29.

-- ---------------------------------------------------------------------------
-- obligations.interval_days: "N days after the previous bill".
-- ---------------------------------------------------------------------------
alter table obligations add column if not exists interval_days int check (interval_days > 0);

-- ---------------------------------------------------------------------------
-- advance_due_date: new p_interval_days branch, evaluated before the other
-- scheduling rules. (Drops the superseded 7-arg overload so its 7-arg call
-- inside the old pay_obligation doesn't survive to confuse the 8-arg default.)
-- ---------------------------------------------------------------------------
drop function if exists advance_due_date(date, text, int, int, int, int, int[]);

create or replace function advance_due_date(
  p_date date,
  p_frequency text,
  p_interval_months int default null,
  p_due_day int default null,
  p_weekday int default null,
  p_nth_occurrence int default null,
  p_installment_months int[] default null,
  p_interval_days int default null
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
    when p_interval_days is not null then (p_date + p_interval_days * interval '1 day')::date
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
-- pay_obligation: carry interval_days through to advance_due_date.
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
  v_interval_days int;
begin
  select organization_id, next_due_date, frequency, interval_months, due_day, weekday, nth_occurrence, installment_months, interval_days
    into v_org, v_next, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence, v_installment_months, v_interval_days
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
        next_due_date = advance_due_date(next_due_date, v_freq, v_interval, v_due_day, v_weekday, v_nth_occurrence, v_installment_months, v_interval_days),
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
-- Convert existing electric obligations to the 29-day rule. Guarded on
-- interval_days so a re-run (idempotency) doesn't touch already-converted
-- bills (due_day is cleared since interval_days now wins anyway).
-- ---------------------------------------------------------------------------
update obligations
set interval_days = 29,
    due_day = null
where category = 'electric'
  and interval_days is null;
