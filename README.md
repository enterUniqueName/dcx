# dcx — Property Operations Management System

Multi-tenant operational awareness for real estate ownership entities. Not an accounting system — QuickBooks remains the system of record; this app tracks obligations, payments, billbacks, and documents so nothing is missed.

## Stack

- SvelteKit (static site, no server — built to `build/` and served from GitHub Pages)
- Supabase (Postgres + Auth + Storage)
- JavaScript, no custom backend

See `docs/DESIGN.md` for the full design. The UI talks to data only through `src/lib/api/`.

## The two halves of this app

This is the most important thing to understand about the project:

- **The UI lives in this repo.** All of `src/` — pages, components, and `src/lib/api/` (the only layer that talks to the database).
- **The database lives in Supabase, not in this repo.** Everything "backend-ish" is Postgres running in the cloud: the tables, the security rules (RLS), the read-model views (`v_*`), and the functions like `pay_obligation`. If the live database and this repo disagree, the app breaks — so keeping them in sync is the whole game.

## How the database is kept in sync (read this)

The schema is defined as **numbered SQL files** in `supabase/migrations/` (`000001_init_schema.sql` …). They are the source of truth for the database, and they must be applied to the live Supabase project **in order, one at a time**:

1. Open the Supabase Dashboard → SQL Editor.
2. Open the newest migration file (the highest number you haven't applied yet), copy the **entire** file.
3. Paste it into the SQL Editor and hit **Run**.
4. If a migration also changes baseline data, re-run `supabase/seed.sql` the same way afterward. It is idempotent (every insert is `on conflict do nothing`), so re-running it is always safe.

Rules that keep this painless:

- **Never edit an applied migration.** Schema changes go in a *new* file: `000018_your_change.sql`. The history stays intact so a fresh database can be rebuilt from scratch.
- Migrations are written to be **re-runnable** (`drop ... if exists`, `create or replace`) so a partial paste can just be run again.
- Views and functions are `drop … if exists` then `create`. If a base table column changes, the views that reference it must be dropped and recreated too (a `create or replace view` cannot remove a referenced column). `000017_remove_property_nickname.sql` is the canonical example.

## Local development

Node 22.23.2 is required (the system Node 14 breaks SvelteKit and the schema test harness). With nvm:

```bash
nvm install 22.23.2 && nvm use 22.23.2
```

```bash
cp .env.example .env     # fill in VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

- `VITE_SUPABASE_URL`: your project URL, `https://<project-ref>.supabase.co`
- `VITE_SUPABASE_ANON_KEY`: the **publishable** key (`sb_publishable_...`) from Supabase → Settings → API Keys. Never the secret key.

Useful commands:

```bash
npm run check     # svelte-check: 0 errors + 0 warnings before you're done
npm run build     # produces the static site in build/
npm run preview   # serve the built site locally
```

## Testing schema changes before they go live

Before a migration touches the live database, it is validated against a local in-memory Postgres (PGlite):

- `supabase/test/validate.mjs` — applies **all** migrations + seed from scratch, then runs ~130 assertions (RLS, views, functions, seed data).
- `supabase/test/upgrade-test.mjs` — simulates upgrading the live database: seeds with the 000009-era seed, then applies 000010+ on top.
- `supabase/test/idempotency-test.mjs` — applies each migration twice and asserts the schema is unchanged.

```bash
cd supabase/test && npm install && node validate.mjs
```

All three must pass before a migration is pasted into Supabase. This is the safety net that makes the copy-paste workflow safe.

## Deploy

Deployment is manual — there is no CI workflow. Every time you want the live site updated:

```bash
npm run build
```

Then push the contents of `build/` to the `gh-pages` branch (the built site lives at the root of that branch). In GitHub Desktop: commit the `build/` output to `gh-pages` and push. GitHub Pages serves it at https://enterUniqueName.github.io/dcx.

Login credentials can be created with Dave.

## Future considerations

- **Rent payment tracking** — `rent_schedule` records the rent amount per period, but there is no way to track whether tenants have paid, how much is owed, or who is behind. A `rent_payments` table and an arrears view would close this gap.
- **Loan detail pages** — loans are listed but have no detail page (`/loans/[id]`). A detail view would let users drill into a specific loan's payment history and balance.
- **Property → entity auto-fill on templates** — when creating an obligation template, selecting a property should auto-fill the ownership entity from the property record. (Partially implemented in the form; could be extended to the bill creation flow.)
- **Rent receivables vs. expense payables** — the obligations system tracks expenses the owner pays. Rent is income the owner receives. These are different flows and may warrant separate modules.
