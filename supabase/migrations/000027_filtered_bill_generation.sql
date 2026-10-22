-- Add optional template filters for bulk bill generation. A trusted scheduled
-- call with no organization processes every organization; authenticated calls
-- remain restricted to an organization the user can write.
drop function public.generate_bills(uuid, date);

create function public.generate_bills(
  p_organization_id uuid default null,
  p_target_date date default null,
  p_ownership_entity_id uuid default null,
  p_property_id uuid default null,
  p_category text default null
) returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid := p_organization_id;
  v_target date := coalesce(p_target_date, current_date + interval '180 days');
  v_created int := 0;
  v_all_orgs boolean := false;
  t record;
  v_last date;
  v_next date;
  v_amount numeric(12, 2);
begin
  if auth.uid() is null then
    if session_user not in ('postgres', 'supabase_admin') then
      raise exception 'not authenticated';
    end if;
    v_all_orgs := v_org is null;
  else
    if v_org is null then
      select organization_id into v_org from current_orgs() limit 1;
    end if;
    if v_org is null then
      return 0;
    end if;
    if not can_write_org(v_org) then
      raise exception 'permission denied';
    end if;
  end if;

  for t in
    select o.*
    from obligations o
    where o.series_id is null
      and o.kind = 'template'
      and o.status = 'open'
      and o.frequency <> 'one_time'
      and o.next_due_date is not null
      and (v_all_orgs or o.organization_id = v_org)
      and (p_ownership_entity_id is null or o.ownership_entity_id = p_ownership_entity_id)
      and (p_property_id is null or o.property_id = p_property_id)
      and (p_category is null or o.category = p_category)
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
        t.organization_id, t.id, 'bill', t.ownership_entity_id, t.property_id,
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
        t.organization_id, t.id, 'bill', t.ownership_entity_id, t.property_id,
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

revoke all on function public.generate_bills(uuid, date, uuid, uuid, text) from public, anon;
grant execute on function public.generate_bills(uuid, date, uuid, uuid, text) to authenticated;
