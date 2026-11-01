-- Oferta con la que se hizo una compra, en JSON: tipo, cantidad, paga, porcentaje, precio_pack, precio_normal.
-- null = se compró a precio normal. precio_total sigue siendo lo que se pagó de verdad.
alter table public.compras add column if not exists oferta text;
