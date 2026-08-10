-- 000014_entity_access.sql
-- Entity-scoped partner access: grant a user read-only visibility into a single
-- ownership entity (its properties, tenants, loans, obligations, payments,
-- billbacks and documents) without exposing the rest of the organization.
--
-- Design:
--   * entity_access rows = "this user may see this entity inside this org".
--   * Select policies across every domain table are rewritten so a scoped user
--     sees only rows reachable from a granted entity. All read models are
--     security_invoker views, so every page scopes automatically.
--   * Write policies are unchanged (a scoped partner is a 'viewer' member and
--     stays read-only). pay_obligation is hardened so even its security-definer
--     body refuses anyone without write access to the org.
--   * grant/revoke/detail go through admin-guarded security-definer RPCs.

-- ---------------------------------------------------------------------------
-- Grant table
-- ---------------------------------------------------------------------------
create table if not exists entity_access (
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid not null references ownership_entities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('viewer', 'editor')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (organization_id, ownership_entity_id, user_id)
);
create index if not exists entity_access_user_idx
  on entity_access (user_id, organization_id);

alter table entity_access enable row level security;
-- Management goes through the definer RPCs below; these policies are defense in
-- depth so the raw table is only ever manageable by org admins.
drop policy if exists "entity_access_select_admin" on entity_access;
create policy "entity_access_select_admin" on entity_access
  for select using (is_org_admin(organization_id));
drop policy if exists "entity_access_insert_admin" on entity_access;
create policy "entity_access_insert_admin" on entity_access
  for insert with check (is_org_admin(organization_id));
drop policy if exists "entity_access_update_admin" on entity_access;
create policy "entity_access_update_admin" on entity_access
  for update using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));
drop policy if exists "entity_access_delete_admin" on entity_access;
create policy "entity_access_delete_admin" on entity_access
  for delete using (is_org_admin(organization_id));

-- ---------------------------------------------------------------------------
-- Scope helpers
-- ---------------------------------------------------------------------------

-- True when the caller is a viewer member who holds at least one grant in the
-- org. Non-viewer members (owner/admin/member) are never scoped, even if a
-- grant row exists for them, so an admin can't accidentally shrink their own
-- (or a full member's) view by granting them an entity.
create or replace function is_entity_scoped(p_org uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from entity_access a
    join org_members m
      on m.organization_id = a.organization_id and m.user_id = a.user_id
    where a.user_id = auth.uid()
      and a.organization_id = p_org
      and m.role = 'viewer'
  );
$$;

-- The ownership entities the caller may see in p_org: their granted entities
-- when scoped, or every entity in the org otherwise. Derived only from
-- auth.uid() and the caller's own membership, so it never leaks other
-- users' grants or other orgs' rows.
create or replace function visible_entities(p_org uuid)
returns setof uuid
language sql stable security definer
as $$
  select ownership_entity_id
  from entity_access
  where user_id = auth.uid() and organization_id = p_org
  union
  select id
  from ownership_entities
  where organization_id = p_org
    and not is_entity_scoped(p_org);
$$;

-- An obligation is visible if it is reachable from a visible entity: directly,
-- via its property, via its loan, or via its tenant's property.
create or replace function obligation_in_scope(p_oblig uuid, p_org uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from obligations o
    where o.id = p_oblig
      and o.organization_id = p_org
      and (
        o.ownership_entity_id in (select visible_entities(p_org))
        or (o.property_id is not null and (
              select pr.ownership_entity_id from properties pr
              where pr.id = o.property_id
            ) in (select visible_entities(p_org)))
        or (o.loan_id is not null and (
              select l.ownership_entity_id from loans l
              where l.id = o.loan_id
            ) in (select visible_entities(p_org)))
        or (o.tenant_id is not null and (
              select pr2.ownership_entity_id
              from tenants t left join properties pr2 on pr2.id = t.property_id
              where t.id = o.tenant_id
            ) in (select visible_entities(p_org)))
      )
  );
$$;

-- A billback is visible if either side's entity is visible or its obligation
-- is visible.
create or replace function billback_in_scope(p_billback uuid, p_org uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from billbacks b
    where b.id = p_billback
      and b.organization_id = p_org
      and (
        b.from_ownership_entity_id in (select visible_entities(p_org))
        or b.to_ownership_entity_id in (select visible_entities(p_org))
        or (b.obligation_id is not null and obligation_in_scope(b.obligation_id, p_org))
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Scoped select policies (replace the org-only select policies from 000002)
-- ---------------------------------------------------------------------------

-- ownership_entities
drop policy if exists "entities_select" on ownership_entities;
drop policy if exists "entities_select_scoped" on ownership_entities;
create policy "entities_select_scoped" on ownership_entities
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or id in (select visible_entities(organization_id)))
  );

-- properties
drop policy if exists "properties_select" on properties;
drop policy if exists "properties_select_scoped" on properties;
create policy "properties_select_scoped" on properties
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or ownership_entity_id in (select visible_entities(organization_id)))
  );

-- tenants (reachable via their property; unassigned tenants stay hidden)
drop policy if exists "tenants_select" on tenants;
drop policy if exists "tenants_select_scoped" on tenants;
create policy "tenants_select_scoped" on tenants
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or property_id in (
           select id from properties
           where ownership_entity_id in (select visible_entities(organization_id))
         ))
  );

-- loans
drop policy if exists "loans_select" on loans;
drop policy if exists "loans_select_scoped" on loans;
create policy "loans_select_scoped" on loans
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or ownership_entity_id in (select visible_entities(organization_id)))
  );

-- obligations
drop policy if exists "obligations_select" on obligations;
drop policy if exists "obligations_select_scoped" on obligations;
create policy "obligations_select_scoped" on obligations
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or obligation_in_scope(id, organization_id))
  );

-- payments (reachable via their obligation, billback, or funding entity)
drop policy if exists "payments_select" on payments;
drop policy if exists "payments_select_scoped" on payments;
create policy "payments_select_scoped" on payments
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or obligation_in_scope(obligation_id, organization_id)
         or billback_in_scope(billback_id, organization_id)
         or ownership_entity_id in (select visible_entities(organization_id)))
  );

-- billbacks
drop policy if exists "billbacks_select" on billbacks;
drop policy if exists "billbacks_select_scoped" on billbacks;
create policy "billbacks_select_scoped" on billbacks
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or billback_in_scope(id, organization_id))
  );

-- documents (scoped by what they are attached to; vendor documents stay
-- org-wide only, so they are hidden from scoped users)
drop policy if exists "documents_select" on documents;
drop policy if exists "documents_select_scoped" on documents;
create policy "documents_select_scoped" on documents
  for select using (
    organization_id in (select current_orgs())
    and (not is_entity_scoped(organization_id)
         or (entity_type = 'ownership_entity'
             and entity_id in (select visible_entities(organization_id)))
         or (entity_type = 'property'
             and entity_id in (select id from properties
               where ownership_entity_id in (select visible_entities(organization_id))))
         or (entity_type = 'loan'
             and entity_id in (select id from loans
               where ownership_entity_id in (select visible_entities(organization_id))))
         or (entity_type = 'tenant'
             and entity_id in (select id from tenants
               where property_id in (select id from properties
                 where ownership_entity_id in (select visible_entities(organization_id)))))
         or (entity_type = 'obligation' and obligation_in_scope(entity_id, organization_id))
         or (entity_type = 'billback' and billback_in_scope(entity_id, organization_id)))
  );

-- ---------------------------------------------------------------------------
-- Write-path hardening
-- ---------------------------------------------------------------------------
-- pay_obligation is security definer (bypasses RLS), and its only guard was
-- org membership — a scoped viewer is a member and could otherwise pay bills.
-- Require write access so only owner/admin/member can pay.
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

-- ---------------------------------------------------------------------------
-- Admin RPCs (security definer because auth.users is not visible to app roles)
-- ---------------------------------------------------------------------------

-- Grant a user read-only access to one entity. Adds them to the org as a
-- viewer if they aren't already a member (they must already have an account).
create or replace function grant_entity_access(
  p_org uuid,
  p_email text,
  p_entity uuid,
  p_role text default 'viewer'
) returns uuid
language plpgsql security definer
as $$
declare
  v_user uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not is_org_admin(p_org) then
    raise exception 'only an organization admin can grant entity access';
  end if;
  if p_role <> 'viewer' then
    raise exception 'only viewer access is supported';
  end if;

  select id into v_user
  from auth.users
  where email = lower(p_email);
  if v_user is null then
    raise exception 'no account found for %', p_email;
  end if;

  if not exists (select 1 from ownership_entities
                 where id = p_entity and organization_id = p_org) then
    raise exception 'entity does not belong to the organization';
  end if;

  -- Make them a member (viewer) if they aren't already — required to sign in
  -- to the org at all. Never downgrades an existing admin/member role.
  insert into org_members (organization_id, user_id, role)
  values (p_org, v_user, 'viewer')
  on conflict (organization_id, user_id) do nothing;

  insert into entity_access (organization_id, ownership_entity_id, user_id, role, created_by)
  values (p_org, p_entity, v_user, p_role, auth.uid())
  on conflict (organization_id, ownership_entity_id, user_id)
  do update set role = excluded.role;

  return v_user;
end;
$$;

-- Remove a user's entity grants in the org. If they were brought in solely as
-- an access partner (still a viewer and left with no grants), drop their
-- membership too so they lose all access.
create or replace function revoke_entity_access(p_org uuid, p_user uuid)
returns void
language plpgsql security definer
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not is_org_admin(p_org) then
    raise exception 'only an organization admin can revoke entity access';
  end if;

  delete from entity_access
  where organization_id = p_org and user_id = p_user;

  delete from org_members
  where organization_id = p_org and user_id = p_user and role = 'viewer'
    and not exists (
      select 1 from entity_access
      where organization_id = p_org and user_id = p_user
    );
end;
$$;

-- Grants with entity names + emails for the admin UI.
create or replace function entity_access_detail(p_org uuid)
returns table (
  user_id uuid,
  email text,
  display_name text,
  ownership_entity_id uuid,
  entity_name text,
  role text,
  created_at timestamptz
)
language plpgsql security definer
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not is_org_admin(p_org) then
    raise exception 'only an organization admin can view entity access';
  end if;

  return query
  select a.user_id, u.email, p.display_name, a.ownership_entity_id,
         e.name as entity_name, a.role, a.created_at
  from entity_access a
  join auth.users u on u.id = a.user_id
  left join profiles p on p.id = a.user_id
  join ownership_entities e on e.id = a.ownership_entity_id
  where a.organization_id = p_org
  order by e.name, u.email;
end;
$$;
