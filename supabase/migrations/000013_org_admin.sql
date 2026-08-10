-- 000013_org_admin.sql
-- Admin tooling for the Organizations page (owner/admin only):
--   * invite_member       — add someone to an org by email (looks up auth.users)
--   * org_members_detail  — full member roster (email + display name + role)
-- Both are security definer because auth.users (and profiles, for roster
-- display) are not visible to app roles; each is guarded by is_org_admin()
-- from 000002 so only org admins can resolve emails or read the roster.

-- Invite an existing user into an organization by email.
create or replace function invite_member(p_org uuid, p_email text, p_role text default 'member')
returns uuid
language plpgsql security definer
as $$
declare
  v_user uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not is_org_admin(p_org) then
    raise exception 'only an organization admin can invite members';
  end if;
  if p_role not in ('owner', 'admin', 'member', 'viewer') then
    raise exception 'invalid role';
  end if;

  select id into v_user
  from auth.users
  where email = lower(p_email);

  if v_user is null then
    raise exception 'no account found for %', p_email;
  end if;

  if exists (select 1 from org_members where organization_id = p_org and user_id = v_user) then
    raise exception 'already a member';
  end if;

  insert into org_members (organization_id, user_id, role)
  values (p_org, v_user, p_role);

  return v_user;
end;
$$;

-- Full roster (emails + display names + roles) for the admin UI.
create or replace function org_members_detail(p_org uuid)
returns table (
  user_id uuid,
  email text,
  display_name text,
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
    raise exception 'only an organization admin can view members';
  end if;

  return query
  select m.user_id, u.email, p.display_name, m.role, m.created_at
  from org_members m
  left join auth.users u on u.id = m.user_id
  left join profiles p on p.id = m.user_id
  where m.organization_id = p_org
  order by p.display_name nulls last, u.email;
end;
$$;
