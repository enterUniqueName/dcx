# Property Operations Management System — Design Document

Status: Draft for review
Scope: v1 (operational awareness; QuickBooks remains system of record for accounting)

---

## 1. Purpose

A multi-tenant **Property Operations Management System**. It does not do accounting. QuickBooks stays the system of record for financial reporting; this app answers *operational* questions:

- What bills are due this week? What is overdue?
- What obligations have been received but not yet paid?
- How much cash will each ownership entity need this month?
- What did one entity (e.g. PLB) pay on behalf of another entity?
- Which billbacks/reimbursements are still outstanding?
- When was something paid, and what documents are attached?

The first deployment serves one client (~7 entities, 16 properties, 13 loans, 13 tenants), but the architecture supports many organizations from day one.

## 2. Guiding Principle

Every screen answers: **"What requires my attention today?"** Clarity, visibility, and operational awareness across entities and properties. If a feature does not serve that mission, it is out of scope for v1.

## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│  SvelteKit static app  (deployed to GitHub Pages)│
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  UI  — routes + components (modules)      │  │
│  └──────────────────┬────────────────────────┘  │
│  ┌──────────────────▼────────────────────────┐  │
│  │  src/lib/api/*  — async facade             │  │
│  │  (the ONLY way the UI touches data)        │  │
│  └──────────────────┬────────────────────────┘  │
└─────────────────────┼───────────────────────────┘
                      │  HTTPS via supabase-js
┌─────────────────────▼───────────────────────────┐
│  Supabase                                       │
│   Auth        — email/password + sessions       │
│   Postgres    — schema + RLS + read-model views │
│   Storage     — documents (org-scoped folders)  │
└─────────────────────────────────────────────────┘
```

Decisions implied by the diagram:

- **No custom backend server.** The app is 100% static. The client talks to Supabase directly.
- **No TypeScript** unless explicitly requested. Plain JavaScript.
- **API abstraction layer.** The UI imports `api` from `src/lib/api` and nothing else. Today it calls Supabase; tomorrow it could call a different provider without touching UI code. Every method is `async`.

### 3.1 Static-site implications

Because there is no server:

- All auth/session handling is **client-side** (`supabase.auth.getSession()` + a Svelte store).
- Dynamic routes (`/obligations/[id]`) cannot be pre-rendered for every id. We use the standard SvelteKit + GitHub Pages pattern:
  - `adapter-static` with `ssr = false`, `prerender = true`
  - `fallback: '404.html'` — GitHub Pages serves `404.html` for any unknown path, which is our app shell; SvelteKit's client-side router then renders the requested route. Deep links and refreshes work.
- `paths.base = '/dcx/'` (repository name) set at build time.
- Supabase anon key is public by design; **all security comes from Row Level Security**, never from hiding the key.

## 4. Multi-tenant model

Every data table carries `organization_id`. RLS scopes every query/write to the caller's organizations.

```
Organization  (the "client" / consulting customer)
 └── OrgMembers (which users belong, and their role)
 └── OrganizationSettings
 └── OwnershipEntity        (LLC, LP, trust...)
      └── Property
      └── Loan
      └── Obligation
           └── Payment
      └── Billback (from → to entity)
 └── Tenant, Vendor, Document
```

Roles: `owner`, `admin`, `member`, `viewer`.

- `viewer` = read-only (enforced in RLS policies).
- `owner`/`admin` manage org members and settings.
- One user can belong to multiple organizations; an **org switcher** in the top bar sets the active org. All `api.*` calls are scoped to the active org.

The active org id lives in a client-side store (persisted to `localStorage`). Every API method reads it internally — callers never pass it.

## 5. Data model

Tables (all with `organization_id`, `created_at`, `updated_at` where mutable):

### 5.1 Identity & membership

| Table | Purpose | Notes |
|---|---|---|
| `organizations` | tenant/consulting client | `name`, `slug` (unique) |
| `profiles` | per-user display info | `id` = `auth.users.id`; `default_organization_id` |
| `org_members` | user ↔ org + role | `unique(organization_id, user_id)` |

### 5.2 Domain tables

| Table | Purpose | Key columns |
|---|---|---|
| `ownership_entities` | LLC/LP/trust that owns assets | `name`, `entity_type`, `ein`, `status` |
| `properties` | physical property | `ownership_entity_id`, `name`, `address*`, `property_type`, `unit_count`, `status` |
| `tenants` | tenant contacts (future lease module) | `property_id`, `name`, `email`, `phone`, `status`, `move_in_date` |
| `vendors` | utilities, insurers, tax authorities, contractors | `name`, `category`, `email`, `phone`, `payment_terms`, `active` |
| `loans` | loan obligations | `ownership_entity_id`, `property_id`, `lender`, `loan_number`, `original_amount`, `current_balance`, `interest_rate`, `origination_date`, `maturity_date`, `payment_frequency`, `monthly_payment`, `status` |
| `obligations` | the core entity — anything owed | see below |
| `payments` | a payment against an obligation | `obligation_id`, `ownership_entity_id` (funding entity), `billback_id`, `amount`, `paid_date`, `method`, `reference` |
| `billbacks` | reimbursement from one entity to another (e.g. PLB → property entity) | `from_ownership_entity_id`, `to_ownership_entity_id`, `obligation_id`, `amount`, `status`, `issued_date`, `due_date` |
| `documents` | file metadata (files live in Storage) | polymorphic `entity_type` + `entity_id`, `file_name`, `mime_type`, `size_bytes`, `storage_path` |
| `organization_settings` | per-org config | `default_currency` (v1: USD only) |

### 5.3 `obligations` — the heart of the app

```sql
create table obligations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  property_id        uuid references properties(id) on delete set null,
  vendor_id          uuid references vendors(id) on delete set null,
  loan_id            uuid references loans(id) on delete set null,
  tenant_id          uuid references tenants(id) on delete set null,

  name        text not null,
  description text,
  category    text not null default 'other'
              check (category in ('utility','tax','insurance','loan_payment',
                                  'maintenance','service','reimbursement','other')),
  amount      numeric(12,2) not null check (amount >= 0),

  frequency       text not null default 'one_time'
                  check (frequency in ('one_time','monthly','quarterly',
                                       'semi_annual','annual','custom')),
  interval_months int,                    -- when frequency = 'custom'
  due_day         int check (due_day between 1 and 31),
  next_due_date   date not null,

  billing_start   date,                   -- period this obligation covers
  billing_end     date,
  received        boolean not null default false,   -- bill/invoice received
  received_date   date,

  status      text not null default 'open'
              check (status in ('open','paid','canceled')),
  portal_url  text,                       -- link to vendor portal/invoice
  notes       text
);
```

Design decisions:

- **Status is `open | paid | canceled`. "Overdue" is derived** (`status='open' AND next_due_date < today`), never stored — it cannot go stale.
- **Recurring obligations are a single record, not per-period instances.** When paid, `next_due_date` advances by the frequency and the record **returns to `open`** (the series continues; only `one_time` obligations flip to `paid`). Payment history lives in `payments`, which is the source of truth for "when was X paid." This keeps a recurring obligation always visible in attention lists and avoids orphaned instances, and it works without a backend/cron. (See §7.2 for the atomic pay flow.)
- **`received`** answers "which bills have we gotten but not paid" — a core attention driver. Setting it records `received_date`.
- Nullable links keep v1 simple and future-friendly: `maintenance` → same table with `category='maintenance'`; lease/insurance modules just populate `tenant_id`/`category` and attach documents.

## 6. Security — Row Level Security

- RLS is **enabled on every table** and **enforced** (a UI that bypasses it gets nothing).
- Central helper (security-definer, returns only the caller's own memberships):

```sql
create function current_orgs()
returns setof uuid language sql stable security definer as $$
  select organization_id from org_members where user_id = auth.uid();
$$;
```

- Policy pattern used everywhere:

```sql
alter table obligations enable row level security;
create policy "members scope obligations"
  on obligations for select
  using (organization_id in (select current_orgs()));
create policy "members write obligations"
  on obligations for insert with check
  (organization_id in (select current_orgs())
   and exists (select 1 from org_members m
               where m.user_id = auth.uid()
                 and m.organization_id = obligations.organization_id
                 and m.role in ('owner','admin','member')));   -- viewers are read-only
-- update/delete similar
```

- `organizations`: `select` scoped to membership; write only `owner`/`admin`.
- `org_members`: `select` own memberships; write only org admins.
- `profiles`: select/update own row.
- `payments` and every other table follow the same pattern.
- **Storage**: a `documents` bucket, paths like `documents/{org_id}/{entity_type}/{entity_id}/{uuid}_{filename}`. Storage policies grant access only when `(storage.foldername(name))[1]::uuid in (select current_orgs())`.

## 7. Read models & workflows

### 7.1 Read models (Postgres views, `security_invoker`)

Complex reads are expressed as **views** (not RPCs) — simpler, RLS keeps applying to them, and the API layer just `select`s from the view name. Views join display names so the UI never hand-builds joins.

- `v_obligations` — obligation + entity/property/vendor/loan names
- `v_payments` — payment + obligation/entity/billback names
- `v_billbacks` — billback + from/to entity names + `amount_paid` (aggregated from `payments`) + computed `balance`
- `v_documents` — document + owning record name + org name
- `v_loans`, `v_tenants` — same pattern

### 7.2 The pay workflow (atomic, one round trip)

Marking an obligation paid is transactional (insert payment + set status + advance `next_due_date` + clear `received`). Implemented as a single stored function so it cannot half-complete:

```sql
create function pay_obligation(
  p_obligation_id uuid,
  p_amount numeric(12,2),
  p_paid_date date,
  p_ownership_entity_id uuid,   -- which entity funded it
  p_method text default null,
  p_reference text default null,
  p_notes text default null
) returns jsonb ...
```

- Raises if the caller lacks access or the obligation isn't `open`.
- Inserts the `payments` row, advances `next_due_date` via a `advance_due_date(date, frequency, interval_months)` helper, clears `received`. Recurring obligations return to `status='open'`; one-time obligations become `status='paid'`.
- The API method `api.markObligationPaid(id, {...})` wraps this call.

`payments.obligation_id` is nullable: a payment may settle a **billback** instead (checked by `obligation_id is not null OR billback_id is not null`). A billback is settled only by reimbursement payments from the debtor entity, never by the originating cross-entity payment — otherwise the trigger below would mark it paid immediately.

Everything else (create/update obligation, mark received, billbacks, documents) is a plain insert/update through the facade — RLS handles scoping.

## 8. API abstraction layer

`src/lib/api/` — the only data-access code in the app.

```
src/lib/api/
  client.js        # shared supabase client (private)
  context.js       # session + active org store (private)
  index.js         # api facade (public surface)
  organizations.js
  entities.js
  properties.js
  tenants.js
  vendors.js
  loans.js
  obligations.js
  payments.js
  billbacks.js
  documents.js
  reports.js
```

Public facade (all async, all org-scoped automatically):

```js
// organization & session
api.getOrganizations()
api.getActiveOrganization()          // org settings + membership
api.setActiveOrganization(id)

// reference data
api.getProperties()
api.getOwnershipEntities()
api.getTenants()
api.getVendors()
api.getLoans()
api.createProperty(data); api.updateProperty(id, patch); api.deleteProperty(id)
api.createOwnershipEntity(data); /* ... etc for each module */

// obligations — the core
api.getObligations({ status, from, to })
api.getObligation(id)
api.getUpcomingObligations({ from, to })
api.getOverdueObligations()
api.getReceivedObligations()         // received but unpaid
api.createObligation(data)
api.updateObligation(id, patch)
api.markObligationReceived(id)
api.markObligationPaid(id, { amount, paidDate, fundingEntityId, method, reference, notes })
api.cancelObligation(id)

// payments
api.getPayments({ obligationId })
api.getPaymentLog({ from, to })
api.deletePayment(id)

// billbacks
api.createBillback(data)
api.getOutstandingBillbacks()
api.getBillbacks({ status })
api.deleteBillback(id)

// documents
api.getDocuments(entityType, entityId)
api.uploadDocument(entityType, entityId, file)
api.deleteDocument(id)

// reports (read models)
api.getCashNeeded(month)             // per-entity totals
api.getCrossEntityPayments({ from, to })  // "what did PLB pay for others?"
api.getDashboardSnapshot()           // all attention-worthy lists in one call
```

Contract notes:

- Methods are small and named for the question they answer.
- The facade is composed from per-module files, so a future "replace Supabase" swap changes only `client.js` and the internals of these files.
- No caller ever imports `client.js` or passes `organization_id`.

## 9. Reporting the key questions

| Question | Where | Data source |
|---|---|---|
| Bills due this week | Dashboard + Reports | `v_obligations` where open, `next_due_date` in window |
| Overdue | Dashboard + Reports | open, `next_due_date < today` (derived) |
| Received, not paid | Dashboard + Reports | `received=true`, `status='open'` |
| Cash needed per entity this month | Dashboard + Reports | open obligations due in month + outstanding billbacks, grouped by `ownership_entity_id` |
| Cross-entity payments (PLB on behalf of…) | Reports | `v_payments` where `payment.ownership_entity_id != obligation.ownership_entity_id` |
| Outstanding billbacks | Dashboard + Reports | `v_billbacks` where `balance > 0` |
| When was X paid | Obligation detail | `v_payments` by obligation |
| Documents on an obligation | Obligation detail | `v_documents` + Storage |

## 10. Auth & session flow

1. Sign in / sign up via Supabase Auth (email + password).
2. On app load (`+layout`), `supabase.auth.getSession()` populates a session store. No session → redirect to `/auth/login`.
3. `api.getOrganizations()` returns the user's orgs; active org from `localStorage`, defaulting to `profiles.default_organization_id`.
4. A new user has no memberships → they see "You don't have access yet" until an admin adds them (an org seed script provisions the first admin).
5. Route-level guard: `src/lib/auth.js` exports an `authStore`; protected routes check it client-side.

## 11. UI structure

```
src/lib/
  api/          # §8
  auth.js       # auth + session stores, guard helper
  components/
    layout/     # Sidebar, TopBar, OrgSwitcher, StatusBadge, MoneyText, DueChip
    ui/         # Button, Input, Select, Modal, Table, EmptyState, ConfirmDialog
    obligation/ # ObligationForm, PaymentForm, ReceivedToggle, DocumentsPanel
  stores/       # active org, filters, toasts
  utils/        # date math (advance_due_date mirror), currency format, csv export
src/routes/
  +layout.svelte
  +page.svelte                 # Dashboard
  auth/login/
  organizations/               # members & settings (admin)
  entities/                    # [id] detail via query param or route
  properties/
  tenants/
  vendors/
  loans/
  obligations/                 # list + detail (detail = payments, documents, billback link)
  payments/
  billbacks/
  documents/                   # library view (filter by entity/type)
  reports/                     # cash forecast, overdue, billback register, payment log, cross-entity
  settings/
```

Dashboard composition (attention first):

- **KPI row:** due this week · overdue · received-not-paid · outstanding billbacks · cash needed this month
- **Lists:** due this week, overdue, received-not-paid, outstanding billbacks
- **Cross-entity payments this month** (what PLB covered for others)

Style: one small UI kit, tables + status badges + due chips (green = on time, amber = this week, red = overdue). No heavy charting library in v1 (numbers + tables beat charts for this job); a plain HTML/CSS bar per entity is enough for the cash forecast.

## 12. Project setup & deployment

SvelteKit, static adapter:

```js
// svelte.config.js
import adapter from '@sveltejs/adapter-static';
export default {
  kit: {
    adapter: adapter({ pages: 'build', assets: 'build',
                       fallback: '404.html', precompress: false }),
    paths: { base: process.env.BASE_PATH ?? '' },
  },
};
```

Root `+layout.js`: `export const ssr = false; export const prerender = true;`

Env (public, committed as `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` is not committed — provided via GitHub Actions secrets / `.env` locally):

```
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

GitHub Actions (`deploy.yml`): on push to `main` → `npm ci && npm run build` with `BASE_PATH=/dcx` → deploy `build/` to `gh-pages`.

## 13. Repo layout

```
dcx/
  docs/DESIGN.md
  src/...
  supabase/
    migrations/       # numbered SQL files (schema → rls → views → functions → storage)
    seed.sql          # idempotent demo/first-client data
  scripts/            # local helpers (seed via psql)
  svelte.config.js / vite.config.js / package.json
  .github/workflows/deploy.yml
```

## 14. Build order (milestones)

| # | Milestone | Exit criteria |
|---|---|---|
| 1 | Scaffold | SvelteKit static app builds; GitHub Pages deploys; empty app shell with sidebar |
| 2 | Supabase schema | Migrations applied; RLS verified (login as A: sees only org A; no rows as unauthenticated) |
| 3 | Auth + org context | Login, session persistence, org switcher; API facade stubs wired to context |
| 4 | Obligations + Payments (core) | CRUD, mark received, atomic pay w/ auto-advance, overdue/upcoming/received lists, detail w/ payment history |
| 5 | Reference data | Entities, Properties, Vendors, Loans, Tenants CRUD |
| 6 | Dashboard | All KPIs + lists from §11 |
| 7 | Billbacks | Create, outstanding balance, settle via payment, dashboard widget |
| 8 | Documents | Upload/attach/list/delete per entity; org-scoped Storage |
| 9 | Reports | Cash forecast, overdue, billback register, payment log, cross-entity payments + CSV export |
| 10 | Seed + polish | First-client seed data (7 entities, 16 props, 13 loans, 13 tenants + realistic obligations), empty states, delete confirmations |

Each milestone ends with a checkable state and is independently demoable.

## 15. Future features (fits without redesign)

| Future | Slots into |
|---|---|
| Lease tracking | `tenants` + new `leases` table (org-scoped), documents |
| Insurance renewals | `obligations` (`category='insurance'`) + documents + dashboard alerts |
| Maintenance / work orders | `obligations` (`category='maintenance'`) + documents |
| Capital projects | new `projects` table (org-scoped), payments re-use |
| Budget tracking | new `budget_periods`/`budget_lines` tables, vs. payments |
| Inspection schedules | new `inspections` table + documents |
| Vendor management | extend `vendors` (contacts, docs, performance) |
| Notifications / email | Supabase Edge Functions or `pg_cron` emitting through email provider — no app server |
| QuickBooks integration | periodic sync job writing obligation/payment facts **into** this app from QB — read-only source stays QB |

All additions are new org-scoped tables + facade methods + a module — no schema-wide change.

## 16. Decisions to confirm

1. **Recurring obligations = single record that auto-advances** on payment (recommended) vs. per-period instances. Recommended: single record.
2. **Role model** `owner/admin/member/viewer`, with `viewer` enforced read-only in RLS. OK?
3. **Currency**: USD-only in v1 via `organization_settings.default_currency`.
4. **Dynamic routes** rely on the GitHub Pages `404.html` fallback technique for deep links. OK?
5. **Amounts** stored as `numeric(12,2)`. Fine for an operational tool (QuickBooks is the ledger).
6. **No charts library** in v1 — tables + lightweight CSS bars.

Full SQL lives in `supabase/migrations/` once approved; a condensed schema is in Appendix A for review.

---

## Appendix A — Condensed schema (for review)

```sql
-- identity & membership
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
    check (role in ('owner','admin','member','viewer')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);
create table organization_settings (
  organization_id uuid primary key references organizations(id) on delete cascade,
  default_currency text not null default 'USD',
  updated_at timestamptz not null default now()
);

-- domain
create table ownership_entities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  entity_type text not null check (entity_type in ('llc','lp','trust','individual','other')),
  ein text,
  status text not null default 'active' check (status in ('active','inactive')),
  notes text
);
create table properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  name text not null,
  address1 text, address2 text, city text, state text, zip text,
  property_type text not null default 'other'
    check (property_type in ('multifamily','residential','commercial','mixed','other')),
  unit_count int not null default 1 check (unit_count >= 0),
  status text not null default 'active' check (status in ('active','inactive')),
  notes text
);
create table tenants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid references properties(id) on delete set null,
  name text not null,
  email text, phone text,
  status text not null default 'active' check (status in ('active','former','prospective')),
  move_in_date date,
  notes text
);
create table vendors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  category text not null default 'other'
    check (category in ('utility','tax','insurance','maintenance','contractor','other')),
  email text, phone text, website text,
  payment_terms text,
  active boolean not null default true,
  notes text
);
create table loans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  property_id uuid references properties(id) on delete set null,
  lender text not null,
  loan_number text,
  original_amount numeric(14,2), current_balance numeric(14,2),
  interest_rate numeric(6,3),
  origination_date date, maturity_date date,
  payment_frequency text not null default 'monthly'
    check (payment_frequency in ('monthly','quarterly','semi_annual','annual','balloon')),
  monthly_payment numeric(12,2),
  status text not null default 'active' check (status in ('active','paid_off','inactive')),
  notes text
);
create table obligations (
  -- see §5.3
);
create table payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  obligation_id uuid references obligations(id) on delete cascade,  -- nullable: may settle a billback instead
  ownership_entity_id uuid references ownership_entities(id) on delete set null,
  billback_id uuid references billbacks(id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  paid_date date not null,
  method text,            -- bank, check, autopay, credit card...
  reference text,         -- check #, confirmation #
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (obligation_id is not null or billback_id is not null)
);
create table billbacks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  from_ownership_entity_id uuid not null references ownership_entities(id) on delete restrict,
  to_ownership_entity_id uuid not null references ownership_entities(id) on delete restrict,
  obligation_id uuid references obligations(id) on delete set null,
  description text,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'outstanding'
    check (status in ('outstanding','partially_paid','paid','waived')),
  issued_date date not null default current_date,
  due_date date,
  notes text,
  check (from_ownership_entity_id <> to_ownership_entity_id)
);
create table documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  entity_type text not null,        -- obligation, property, entity, loan, tenant, vendor, billback...
  entity_id uuid not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  storage_path text not null unique,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
```

Indexes: every table on `organization_id`; `obligations(organization_id, status, next_due_date)`; `payments(obligation_id)`; `payments(organization_id, paid_date)`; `billbacks(organization_id, status)`; `documents(entity_type, entity_id)`.

RLS: helper `current_orgs()` + member/role policies (§6) on every table. Read-model views with `security_invoker`. One stored function, `pay_obligation(...)`, plus `advance_due_date(...)` helper.
