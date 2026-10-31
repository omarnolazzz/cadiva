-- Fotos de productos: la fila guarda la huella y la imagen vive en Storage, en `fotos/<usuario>/<producto>.jpg`.
alter table public.productos add column if not exists foto text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "Cada cuenta lee sus fotos" on storage.objects;
create policy "Cada cuenta lee sus fotos" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Cada cuenta sube sus fotos" on storage.objects;
create policy "Cada cuenta sube sus fotos" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Cada cuenta reemplaza sus fotos" on storage.objects;
create policy "Cada cuenta reemplaza sus fotos" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);
