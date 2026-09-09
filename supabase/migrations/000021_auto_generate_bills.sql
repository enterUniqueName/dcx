-- 000021_auto_generate_bills.sql
-- Enable pg_cron and schedule automatic bill generation on the 1st of each month.
-- Generates bills up to 45 days out (enough for next month + buffer).

-- Enable required extensions.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pgcrypto;

-- Schedule: run at 00:05 UTC on the 1st of every month.
-- Calls generate_bills() which is security definer and skips auth checks
-- when current_user is postgres (which pg_cron uses).
select cron.schedule(
  'auto-generate-bills',
  '5 0 1 * *',
  $$select generate_bills(null, (current_date + interval '45 days')::date)$$
);
