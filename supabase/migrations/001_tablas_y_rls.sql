-- Tablas de Cadiva en Supabase. Cada fila pertenece a una cuenta y solo esa cuenta la ve (RLS).
-- Los borrados son lógicos (borrado = true) para que lleguen a los demás dispositivos.
-- `modificado` lo pone el servidor y sirve como versión de cada fila.

create table if not exists public.productos (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null default '',
  categoria text not null default 'Otro',
  unidad text not null default 'piezas',
  simbolo text not null default 'basket.fill',
  notas text,
  archivado boolean not null default false,
  duracion_estimada_dias integer,
  creado timestamptz not null default now(),
  borrado boolean not null default false,
  modificado timestamptz not null default now()
);

create table if not exists public.compras (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  producto_id uuid,
  fecha timestamptz not null,
  precio_total numeric not null default 0,
  cantidad numeric not null default 1,
  tienda text,
  fecha_agotado timestamptz,
  borrado boolean not null default false,
  modificado timestamptz not null default now()
);

create index if not exists productos_user_id on public.productos (user_id);
create index if not exists compras_user_id on public.compras (user_id);

create or replace function public.tocar_modificado() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.modificado = clock_timestamp();
  return new;
end $$;

drop trigger if exists productos_modificado on public.productos;
create trigger productos_modificado before insert or update on public.productos
  for each row execute function public.tocar_modificado();
drop trigger if exists compras_modificado on public.compras;
create trigger compras_modificado before insert or update on public.compras
  for each row execute function public.tocar_modificado();

alter table public.productos enable row level security;
alter table public.compras enable row level security;

drop policy if exists "Cada cuenta ve sus productos" on public.productos;
create policy "Cada cuenta ve sus productos" on public.productos for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Cada cuenta ve sus compras" on public.compras;
create policy "Cada cuenta ve sus compras" on public.compras for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.productos, public.compras from anon;
grant select, insert, update on public.productos, public.compras to authenticated;
