-- 000005_storage.sql
-- Private documents bucket, org-scoped by folder: documents/{org_id}/...

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "documents_storage_select" on storage.objects
  for select using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1]::uuid in (select public.current_orgs())
  );

create policy "documents_storage_insert" on storage.objects
  for insert with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1]::uuid in (select public.current_orgs())
  );

create policy "documents_storage_update" on storage.objects
  for update using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1]::uuid in (select public.current_orgs())
  );

create policy "documents_storage_delete" on storage.objects
  for delete using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1]::uuid in (select public.current_orgs())
  );
