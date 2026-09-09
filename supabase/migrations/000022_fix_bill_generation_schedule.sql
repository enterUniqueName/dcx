-- 000022_fix_bill_generation_schedule.sql
-- Correct the cron schedule from the 1st to the 20th of each month.

-- Remove the incorrectly scheduled job.
select cron.unschedule('auto-generate-bills');

-- Re-schedule: run at 00:05 UTC on the 20th of every month.
select cron.schedule(
  'auto-generate-bills',
  '5 0 20 * *',
  $$select generate_bills(null, (current_date + interval '45 days')::date)$$
);
