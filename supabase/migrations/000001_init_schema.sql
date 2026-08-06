-- 000001_init_schema.sql
-- Core schema for the Property Operations Management System.
-- Run as the Supabase postgres role (default when using supabase migrations).

-- ---------------------------------------------------------------------------
-- Default grants so authenticated roles can use tables/functions once created.
-- RLS provides the actual access control; these grants just allow the attempt.
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

alter default privileges in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to postgres, anon, authenticated, service_role;

grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all functions in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Identity & membership
-- ---------------------------------------------------------------------------
create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  default_organization_id uuid references organizations(id) on delete set null,
  created_at timestamptz not null default now()
);

create table org_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);
create index org_members_user_idx on org_members (user_id);

create table organization_settings (
  organization_id uuid primary key references organizations(id) on delete cascade,
  default_currency text not null default 'USD',
  updated_at timestamptz not null default now()
);

-- Create a profile row automatically when a user signs up.
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Domain tables
-- ---------------------------------------------------------------------------
create table ownership_entities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  entity_type text not null default 'other'
    check (entity_type in ('llc', 'lp', 'trust', 'individual', 'other')),
  ein text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ownership_entities_org_idx on ownership_entities (organization_id);

create table properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  name text not null,
  address1 text,
  address2 text,
  city text,
  state text,
  zip text,
  property_type text not null default 'other'
    check (property_type in ('multifamily', 'residential', 'commercial', 'mixed', 'other')),
  unit_count int not null default 1 check (unit_count >= 0),
  status text not null default 'active' check (status in ('active', 'inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index properties_org_idx on properties (organization_id);
create index properties_entity_idx on properties (ownership_entity_id);

create table tenants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid references properties(id) on delete set null,
  name text not null,
  email text,
  phone text,
  status text not null default 'active' check (status in ('active', 'former', 'prospective')),
  move_in_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tenants_org_idx on tenants (organization_id);
create index tenants_property_idx on tenants (property_id);

create table vendors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  category text not null default 'other'
    check (category in ('utility', 'tax', 'insurance', 'maintenance', 'contractor', 'other')),
  email text,
  phone text,
  website text,
  payment_terms text,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vendors_org_idx on vendors (organization_id);

create table loans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  property_id uuid references properties(id) on delete set null,
  lender text not null,
  loan_number text,
  original_amount numeric(14, 2),
  current_balance numeric(14, 2),
  interest_rate numeric(6, 3),
  origination_date date,
  maturity_date date,
  payment_frequency text not null default 'monthly'
    check (payment_frequency in ('monthly', 'quarterly', 'semi_annual', 'annual', 'balloon')),
  monthly_payment numeric(12, 2),
  status text not null default 'active' check (status in ('active', 'paid_off', 'inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index loans_org_idx on loans (organization_id);
create index loans_entity_idx on loans (ownership_entity_id);
create index loans_property_idx on loans (property_id);

create table obligations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  property_id uuid references properties(id) on delete set null,
  vendor_id uuid references vendors(id) on delete set null,
  loan_id uuid references loans(id) on delete set null,
  tenant_id uuid references tenants(id) on delete set null,

  name text not null,
  description text,
  category text not null default 'other'
    check (category in ('utility', 'tax', 'insurance', 'loan_payment', 'maintenance', 'service', 'reimbursement', 'other')),
  amount numeric(12, 2) not null check (amount >= 0),

  frequency text not null default 'one_time'
    check (frequency in ('one_time', 'monthly', 'quarterly', 'semi_annual', 'annual', 'custom')),
  interval_months int,
  due_day int check (due_day between 1 and 31),
  next_due_date date not null,

  billing_start date,
  billing_end date,
  received boolean not null default false,
  received_date date,

  status text not null default 'open' check (status in ('open', 'paid', 'canceled')),
  portal_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index obligations_org_idx on obligations (organization_id);
create index obligations_due_idx on obligations (organization_id, status, next_due_date);
create index obligations_entity_idx on obligations (ownership_entity_id);

create table billbacks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  from_ownership_entity_id uuid not null references ownership_entities(id) on delete restrict,
  to_ownership_entity_id uuid not null references ownership_entities(id) on delete restrict,
  obligation_id uuid references obligations(id) on delete set null,
  description text,
  amount numeric(12, 2) not null check (amount > 0),
  status text not null default 'outstanding'
    check (status in ('outstanding', 'partially_paid', 'paid', 'waived')),
  issued_date date not null default current_date,
  due_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_ownership_entity_id <> to_ownership_entity_id)
);
create index billbacks_org_idx on billbacks (organization_id);
create index billbacks_status_idx on billbacks (organization_id, status);

create table payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  obligation_id uuid references obligations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  billback_id uuid references billbacks(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  paid_date date not null,
  method text,
  reference text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (obligation_id is not null or billback_id is not null)
);
create index payments_org_idx on payments (organization_id);
create index payments_obligation_idx on payments (obligation_id);
create index payments_billback_idx on payments (billback_id);
create index payments_paid_date_idx on payments (organization_id, paid_date);

create table documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('obligation', 'property', 'ownership_entity', 'loan', 'tenant', 'vendor', 'billback')),
  entity_id uuid not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  storage_path text not null unique,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index documents_entity_idx on documents (entity_type, entity_id);
create index documents_org_idx on documents (organization_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create trigger trg_organizations_updated
  before update on organizations for each row execute function set_updated_at();
create trigger trg_ownership_entities_updated
  before update on ownership_entities for each row execute function set_updated_at();
create trigger trg_properties_updated
  before update on properties for each row execute function set_updated_at();
create trigger trg_tenants_updated
  before update on tenants for each row execute function set_updated_at();
create trigger trg_vendors_updated
  before update on vendors for each row execute function set_updated_at();
create trigger trg_loans_updated
  before update on loans for each row execute function set_updated_at();
create trigger trg_obligations_updated
  before update on obligations for each row execute function set_updated_at();
create trigger trg_billbacks_updated
  before update on billbacks for each row execute function set_updated_at();
create trigger trg_payments_updated
  before update on payments for each row execute function set_updated_at();
create trigger trg_org_settings_updated
  before update on organization_settings for each row execute function set_updated_at();
