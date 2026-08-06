-- 000002_rls.sql
-- Row Level Security: every data table is scoped to the caller's organizations.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- The organizations the current user belongs to. Security definer: reads
-- org_members as the function owner but is derived only from auth.uid(), so it
-- can never leak another user's memberships.
create or replace function current_orgs()
returns setof uuid
language sql stable security definer
as $$
  select organization_id from org_members where user_id = auth.uid();
$$;

-- May the current user write to a given organization? (owner/admin/member)
create or replace function can_write_org(p_org uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from org_members m
    where m.user_id = auth.uid()
      and m.organization_id = p_org
      and m.role in ('owner', 'admin', 'member')
  );
$$;

-- Is the current user an owner/admin of a given organization?
create or replace function is_org_admin(p_org uuid)
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from org_members m
    where m.user_id = auth.uid()
      and m.organization_id = p_org
      and m.role in ('owner', 'admin')
  );
$$;

-- ---------------------------------------------------------------------------
-- organizations
-- ---------------------------------------------------------------------------
alter table organizations enable row level security;

create policy "orgs_select_members" on organizations
  for select using (id in (select current_orgs()));
create policy "orgs_update_admins" on organizations
  for update using (can_write_org(id)) with check (can_write_org(id));
create policy "orgs_delete_admins" on organizations
  for delete using (can_write_org(id));
-- inserts go through create_organization() (security definer), no policy needed.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
alter table profiles enable row level security;

create policy "profiles_select_self" on profiles
  for select using (id = auth.uid());
create policy "profiles_insert_self" on profiles
  for insert with check (id = auth.uid());
create policy "profiles_update_self" on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- org_members
-- ---------------------------------------------------------------------------
alter table org_members enable row level security;

create policy "members_select_orgs" on org_members
  for select using (organization_id in (select current_orgs()));
create policy "members_insert_admins" on org_members
  for insert with check (
    is_org_admin(organization_id)
    and (select u.id from auth.users u where u.id = user_id) is not null
  );
create policy "members_update_admins" on org_members
  for update using (is_org_admin(organization_id))
  with check (is_org_admin(organization_id));
create policy "members_delete_admins" on org_members
  for delete using (is_org_admin(organization_id));

-- ---------------------------------------------------------------------------
-- organization_settings
-- ---------------------------------------------------------------------------
alter table organization_settings enable row level security;

create policy "settings_select_orgs" on organization_settings
  for select using (organization_id in (select current_orgs()));
create policy "settings_insert_admins" on organization_settings
  for insert with check (can_write_org(organization_id));
create policy "settings_update_admins" on organization_settings
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));

-- ---------------------------------------------------------------------------
-- Domain tables (shared pattern)
--   select:  member of the row's org
--   write:   member with role owner/admin/member (viewers are read-only)
-- ---------------------------------------------------------------------------
alter table ownership_entities enable row level security;
create policy "entities_select" on ownership_entities
  for select using (organization_id in (select current_orgs()));
create policy "entities_insert" on ownership_entities
  for insert with check (can_write_org(organization_id));
create policy "entities_update" on ownership_entities
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "entities_delete" on ownership_entities
  for delete using (can_write_org(organization_id));

alter table properties enable row level security;
create policy "properties_select" on properties
  for select using (organization_id in (select current_orgs()));
create policy "properties_insert" on properties
  for insert with check (can_write_org(organization_id));
create policy "properties_update" on properties
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "properties_delete" on properties
  for delete using (can_write_org(organization_id));

alter table tenants enable row level security;
create policy "tenants_select" on tenants
  for select using (organization_id in (select current_orgs()));
create policy "tenants_insert" on tenants
  for insert with check (can_write_org(organization_id));
create policy "tenants_update" on tenants
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "tenants_delete" on tenants
  for delete using (can_write_org(organization_id));

alter table vendors enable row level security;
create policy "vendors_select" on vendors
  for select using (organization_id in (select current_orgs()));
create policy "vendors_insert" on vendors
  for insert with check (can_write_org(organization_id));
create policy "vendors_update" on vendors
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "vendors_delete" on vendors
  for delete using (can_write_org(organization_id));

alter table loans enable row level security;
create policy "loans_select" on loans
  for select using (organization_id in (select current_orgs()));
create policy "loans_insert" on loans
  for insert with check (can_write_org(organization_id));
create policy "loans_update" on loans
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "loans_delete" on loans
  for delete using (can_write_org(organization_id));

alter table obligations enable row level security;
create policy "obligations_select" on obligations
  for select using (organization_id in (select current_orgs()));
create policy "obligations_insert" on obligations
  for insert with check (can_write_org(organization_id));
create policy "obligations_update" on obligations
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "obligations_delete" on obligations
  for delete using (can_write_org(organization_id));

alter table payments enable row level security;
create policy "payments_select" on payments
  for select using (organization_id in (select current_orgs()));
create policy "payments_insert" on payments
  for insert with check (can_write_org(organization_id));
create policy "payments_update" on payments
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "payments_delete" on payments
  for delete using (can_write_org(organization_id));

alter table billbacks enable row level security;
create policy "billbacks_select" on billbacks
  for select using (organization_id in (select current_orgs()));
create policy "billbacks_insert" on billbacks
  for insert with check (can_write_org(organization_id));
create policy "billbacks_update" on billbacks
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "billbacks_delete" on billbacks
  for delete using (can_write_org(organization_id));

alter table documents enable row level security;
create policy "documents_select" on documents
  for select using (organization_id in (select current_orgs()));
create policy "documents_insert" on documents
  for insert with check (can_write_org(organization_id));
create policy "documents_update" on documents
  for update using (can_write_org(organization_id))
  with check (can_write_org(organization_id));
create policy "documents_delete" on documents
  for delete using (can_write_org(organization_id));
