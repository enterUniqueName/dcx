-- 000004_functions.sql
-- Workflow functions. Security definer so they can operate atomically, but
-- every one verifies the caller's organization membership first.

-- ---------------------------------------------------------------------------
-- advance_due_date: shift a due date forward by a frequency.
-- ---------------------------------------------------------------------------
create or replace function advance_due_date(
  p_date date,
  p_frequency text,
  p_interval_months int default null
) returns date
language sql immutable
as $$
  select case
    when p_frequency = 'monthly'     then (p_date + interval '1 month')::date
    when p_frequency = 'quarterly'   then (p_date + interval '3 months')::date
    when p_frequency = 'semi_annual' then (p_date + interval '6 months')::date
    when p_frequency = 'annual'      then (p_date + interval '1 year')::date
    when p_frequency = 'custom'      then (p_date + (coalesce(p_interval_months, 1) * interval '1 month'))::date
    else p_date
  end;
$$;

-- ---------------------------------------------------------------------------
-- pay_obligation: one atomic operation =
--   insert payment + advance next_due_date + clear received
-- For recurring obligations status returns to 'open' (the series continues);
-- one-time obligations become 'paid'. Payment history lives in payments.
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
begin
  select organization_id, next_due_date, frequency, interval_months
    into v_org, v_next, v_freq, v_interval
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
        next_due_date = advance_due_date(next_due_date, v_freq, v_interval),
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
-- create_organization: security-definer so a new owner can bootstrap a tenant.
-- ---------------------------------------------------------------------------
create or replace function create_organization(p_name text, p_slug text)
returns uuid
language plpgsql security definer
as $$
declare
  v_org uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into organizations (name, slug)
  values (p_name, lower(p_slug))
  returning id into v_org;

  insert into org_members (organization_id, user_id, role)
  values (v_org, auth.uid(), 'owner');

  insert into organization_settings (organization_id)
  values (v_org);

  return v_org;
end;
$$;

-- ---------------------------------------------------------------------------
-- refresh_billback_status: keep billback.status in sync with its payments.
-- ---------------------------------------------------------------------------
create or replace function refresh_billback_status()
returns trigger
language plpgsql
as $$
declare
  b uuid;
  v_paid numeric(12, 2);
begin
  for b in
    select distinct x from (
      select new.billback_id as x
      union all
      select old.billback_id
    ) t
    where x is not null
  loop
    select coalesce(sum(pay.amount), 0) into v_paid
    from payments pay where pay.billback_id = b;

    update billbacks bb
      set status = case
            when v_paid >= bb.amount then 'paid'
            when v_paid > 0 then 'partially_paid'
            else 'outstanding'
          end,
          updated_at = now()
      where bb.id = b;
  end loop;

  return null;
end;
$$;

create trigger payments_refresh_billback
  after insert or update or delete on payments
  for each row execute function refresh_billback_status();
