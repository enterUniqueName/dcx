# dcx — Property Operations Management System

Multi-tenant operational awareness for real estate ownership entities. Not an accounting system — QuickBooks remains the system of record; this app tracks obligations, payments, billbacks, and documents so nothing is missed.

## Stack

- SvelteKit (static site, deployed to GitHub Pages)
- Supabase (Postgres + Auth + Storage)
- JavaScript, no custom backend

See `docs/DESIGN.md` for the full design. The UI talks to data only through `src/lib/api/`.

## Local development

```bash
cp .env.example .env     # fill in VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

Apply the database migrations to a Supabase project with the Supabase CLI:

```bash
supabase link --project-ref <ref>
supabase db push
supabase db seed --file supabase/seed.sql
```

## Deploy

Pushing to `main` builds the static site and deploys it to GitHub Pages via `.github/workflows/deploy.yml`. Set the `SUPABASE_URL` and `SUPABASE_ANON_KEY` repository variables (Settings → Secrets and variables → Actions → Repository variables) — use the publishable key (`sb_publishable_...`), not the secret key. The Pages source must be set to "GitHub Actions" (Settings → Pages).

Live site: https://enterUniqueName.github.io/dcx
