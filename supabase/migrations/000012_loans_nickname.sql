-- 000012_loans_nickname.sql
-- Give loans a short display nickname (like properties) and surface it on the
-- loans page. Before this migration the nickname was trapped in notes as a
-- "nickname: <Name>" prefix (seed era); backfill the new column from that
-- prefix and strip the prefix out of notes.
--
-- v_loans was created in 000006 with `l.*`, so its column list froze before
-- the loans.nickname column existed — the same stale-view trap as v_properties
-- (000011). Drop and recreate it so nickname is exposed to the API.

alter table loans add column if not exists nickname text;

update loans
set nickname = btrim(substring(notes from '^nickname:\s*(.*)$'))
where notes like 'nickname:%';

update loans
set notes = null
where notes like 'nickname:%';

drop view if exists v_loans;
create view v_loans
with (security_invoker = true) as
select
  l.*,
  oe.name as ownership_entity_name,
  coalesce(nullif(p.nickname, ''), p.name) as property_name
from loans l
left join ownership_entities oe on oe.id = l.ownership_entity_id
left join properties p on p.id = l.property_id;
