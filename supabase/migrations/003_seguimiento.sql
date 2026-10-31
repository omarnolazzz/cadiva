-- Seguimiento de cada producto elegido a mano: 'duracion' o 'soloPrecio'.
-- null = automático (la app lo sugiere según el nombre y la categoría).
alter table public.productos add column if not exists seguimiento text
  check (seguimiento is null or seguimiento in ('duracion', 'soloPrecio'));
