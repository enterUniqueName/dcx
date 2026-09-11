-- 000025_auto_generate_two_months.sql
-- Extend the automatic bill-generation window from ~45 days (next month +
-- buffer) to ~75 days (the next two full months), preserving the 20th-of-the-
-- month schedule. Idempotent: already-generated bills are skipped via the
-- (series_id, next_due_date) unique index, so each run only adds the missing
-- month and any bills from newly-created templates.

select cron.unschedule('auto-generate-bills');

-- Re-schedule: run at 00:05 UTC on the 20th of every month, materialize bills
-- through two months out (75 days from the 20th reaches past the end of the
-- following month in every month length, including February).
select cron.schedule(
  'auto-generate-bills',
  '5 0 20 * *',
  $$select generate_bills(null, (current_date + interval '75 days')::date)$$
);