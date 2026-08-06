-- 000006_properties_nickname.sql
-- Add a short display nickname to properties, and prefer it everywhere a
-- property name is surfaced in the read-model views.

alter table properties add column if not exists nickname text;

create or replace view v_obligations
with (security_invoker = true) as
select
  o.*,
  oe.name as ownership_entity_name,
  coalesce(nullif(p.nickname, ''), p.name) as property_name,
  v.name as vendor_name,
  v.category as vendor_category,
  l.lender as loan_name,
  t.name as tenant_name,
  (o.status = 'open' and o.next_due_date < current_date) as is_overdue
from obligations o
left join ownership_entities oe on oe.id = o.ownership_entity_id
left join properties p on p.id = o.property_id
left join vendors v on v.id = o.vendor_id
left join loans l on l.id = o.loan_id
left join tenants t on t.id = o.tenant_id;

create or replace view v_loans
with (security_invoker = true) as
select
  l.*,
  oe.name as ownership_entity_name,
  coalesce(nullif(p.nickname, ''), p.name) as property_name
from loans l
left join ownership_entities oe on oe.id = l.ownership_entity_id
left join properties p on p.id = l.property_id;

create or replace view v_tenants
with (security_invoker = true) as
select
  t.*,
  coalesce(nullif(p.nickname, ''), p.name) as property_name
from tenants t
left join properties p on p.id = t.property_id;

create or replace view v_documents
with (security_invoker = true) as
select
  d.*,
  coalesce(
    o.name,
    coalesce(nullif(pr.nickname, ''), pr.name),
    oe.name,
    l.lender,
    t.name,
    v.name,
    b.description
  ) as entity_name
from documents d
left join obligations o on d.entity_type = 'obligation' and o.id = d.entity_id
left join properties pr on d.entity_type = 'property' and pr.id = d.entity_id
left join ownership_entities oe on d.entity_type = 'ownership_entity' and oe.id = d.entity_id
left join loans l on d.entity_type = 'loan' and l.id = d.entity_id
left join tenants t on d.entity_type = 'tenant' and t.id = d.entity_id
left join vendors v on d.entity_type = 'vendor' and v.id = d.entity_id
left join billbacks b on d.entity_type = 'billback' and b.id = d.entity_id;
