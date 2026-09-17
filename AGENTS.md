# AGENTS.md

Instructions for AI coding assistants working in this repo.

## Project
- SvelteKit 2 + Svelte 5 app, static adapter, Supabase backend (Postgres + Storage + Auth).
- Svelte 5 runes style bound via `bind:checked`/`bind:value`; existing components do NOT use `{#snippet}` — match the patterns in current components.

## Toolchain
- Default shell node is v14 and breaks on modern syntax (`??=`). Use the version in `.nvmrc` (22):
  ```sh
  source ~/.nvm/nvm.sh && nvm use
  ```
- Verify changes with `npx svelte-check --threshold error` and `npm run build` (both should be 0 errors).

## Database access
- `.env` holds only the public anon key; there is no service-role key anywhere. RLS on every table requires an authenticated session (`current_orgs()`/`can_write_org()`), so scripts cannot read or delete data anonymously.
- One-off data changes (deletes, fixes) are done by the user in the Supabase SQL editor, or the user runs a generated `.sql`. Provide preview SQL before destructive statements; never ask them to paste secrets.

## Error handling
- Every Supabase table/RPC/storage error funnels through `src/lib/api/client.js`:
  - `unwrap()`) throws for callers,
  - `friendlyError()`) translates SQLSTATE codes and named constraints (`billbacks_check`, `leases_tenant_id_key`, etc.) into human-readable messages that explain *why*, not DB lingo.
- New API modules must route errors through `unwrap()`/`friendlyError()`. Keep UI-facing messages plain-English.

## Migrations & SQL
- Migrations live in `supabase/migrations/0000NN_*.sql`.
- Seed data in `supabase/seed.sql` uses fixed UUIDs (org `11000000-0000-4000-8000-000000000001`, PLB entity `21000000-0000-4000-8000-000000000003`, etc.) — keep them stable.
- Interdependent views: `v_obligations`, `v_billbacks`, and `v_cash_needed` reference each other. A migration that recreates `v_obligations` or `v_billbacks` MUST also drop/recreate `v_cash_needed` first (otherwise `2BP01 cannot drop view ... because other objects depend on it`).
- Automatic recurring-bill generation: pg_cron job named `auto-generate-bills`, runs `5 0 20 * *` (20th, 00:05 UTC), target `current_date + 75 days` (two months out). To change the window, reschedule via `cron.unschedule('auto-generate-bills')` + `cron.schedule(...)` in a migration.
- `generate_bills()` is idempotent via `(series_id, next_due_date)` unique index — already-created bills are skipped.
- Manual "Generate now" in the UI targets `today + 75 days` (see `src/lib/api/templates.js`).

## Conventions
- Do NOT `git commit/push` unless the user explicitly asks.
- `.env` / `.env.*` are git-ignored — never commit secrets.
- Architecture/design notes live in `docs/DESIGN.md`.
- Validation tests live in `supabase/test/validate.mjs` and `supabase/test/upgrade-test.mjs`.