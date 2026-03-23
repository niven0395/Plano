insert into storage.buckets (id, name, public)
values ('vendor-galleries', 'vendor-galleries', false)
on conflict (id) do nothing;

drop policy if exists "Anyone can read vendor gallery objects" on storage.objects;
create policy "Anyone can read vendor gallery objects"
on storage.objects for select
using (bucket_id = 'vendor-galleries');

drop policy if exists "Vendors can upload own gallery objects" on storage.objects;
create policy "Vendors can upload own gallery objects"
on storage.objects for insert
with check (
  bucket_id = 'vendor-galleries'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "Vendors can update own gallery objects" on storage.objects;
create policy "Vendors can update own gallery objects"
on storage.objects for update
using (
  bucket_id = 'vendor-galleries'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'vendor-galleries'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "Vendors can delete own gallery objects" on storage.objects;
create policy "Vendors can delete own gallery objects"
on storage.objects for delete
using (
  bucket_id = 'vendor-galleries'
  and auth.uid()::text = (storage.foldername(name))[1]
);
