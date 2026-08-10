-- 000011_v_properties_nickname.sql
-- v_properties was created in 000003 with `pr.*`, so its column list froze
-- before the nickname column (000006) existed. Recreate the view so nickname
-- is exposed (and prefer it for display, matching the other read-model
-- views). Fixes the entity expansion error "column v_properties.nickname does
-- not exist" and the properties page silently showing blank nicknames.

-- pr.* re-expands with nickname in the middle of the column list, which
-- create or replace cannot do — drop and recreate instead.
drop view if exists v_properties;
create view v_properties
with (security_invoker = true) as
select
  pr.*,
  coalesce(nullif(pr.nickname, ''), pr.name) as property_name,
  oe.name as ownership_entity_name
from properties pr
left join ownership_entities oe on oe.id = pr.ownership_entity_id;
