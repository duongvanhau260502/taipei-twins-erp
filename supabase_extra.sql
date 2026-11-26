-- =====================================================================
-- ERP Vat tu MEP – Taipei Twins : script BO SUNG cho Supabase
-- Chay 1 lan trong Supabase > SQL Editor (an toan khi chay lai nhieu lan).
-- Chay SAU khi da tao 9 bang va RLS ban dau.
-- =====================================================================

-- 1) Cot ext: giu nguyen toan bo du lieu goc cua web (ma dong cu, ghi chu duyet, lich su...)
--    de chuyen tu Firebase/OneDrive sang Supabase khong mat thong tin.
alter table public.order_items            add column if not exists ext jsonb not null default '{}'::jsonb;
alter table public.warehouse_transactions add column if not exists ext jsonb not null default '{}'::jsonb;
create index if not exists order_items_order_id_idx on public.order_items(order_id);

-- 2) Ham tra ve vai tro cua nguoi dang dang nhap (security definer de tranh de quy RLS)
create or replace function public.tt_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.user_profiles where id = auth.uid()
$$;
grant execute on function public.tt_role() to authenticated;

-- 3) Bang app_kv: noi luu cac du lieu con lai cua web (cau hinh, NCC, bao gia, to hop, anh ho so...)
create table if not exists public.app_kv (
  coll       text        not null,
  id         text        not null,
  val        jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (coll, id)
);
alter table public.app_kv enable row level security;

-- Cac nhom du lieu GIA: chi ADMIN / QS / CHT / CHP doc-ghi. GS va KHO KHONG doc duoc.
--   quotes, tpgia  : bao gia NCC, don gia tap phi
--   poprice        : don gia tung dong don hang
--   moveup         : don gia luc nhap kho
--   catprice       : don gia trong danh muc tu them
drop policy if exists app_kv_select on public.app_kv;
create policy app_kv_select on public.app_kv for select to authenticated
  using ( public.tt_role() is not null and ( coll not in ('quotes','tpgia','poprice','moveup','catprice')
          or public.tt_role() in ('ADMIN','QS','CHT','CHP') ) );

drop policy if exists app_kv_insert on public.app_kv;
create policy app_kv_insert on public.app_kv for insert to authenticated
  with check ( public.tt_role() is not null and ( coll not in ('quotes','tpgia','poprice','moveup','catprice')
               or public.tt_role() in ('ADMIN','QS','CHT','CHP') ) );

drop policy if exists app_kv_update on public.app_kv;
create policy app_kv_update on public.app_kv for update to authenticated
  using      ( public.tt_role() is not null and ( coll not in ('quotes','tpgia','poprice','moveup','catprice')
               or public.tt_role() in ('ADMIN','QS','CHT','CHP') ) )
  with check ( public.tt_role() is not null and ( coll not in ('quotes','tpgia','poprice','moveup','catprice')
               or public.tt_role() in ('ADMIN','QS','CHT','CHP') ) );

drop policy if exists app_kv_delete on public.app_kv;
create policy app_kv_delete on public.app_kv for delete to authenticated
  using ( public.tt_role() is not null and ( coll not in ('quotes','tpgia','poprice','moveup','catprice')
          or public.tt_role() in ('ADMIN','QS','CHT','CHP') ) );

-- 4) Realtime: bat cho cac bang web lang nghe (bo qua bang da co san trong publication)
do $$
declare t text;
begin
  foreach t in array array['orders','order_items','warehouse_transactions','app_kv',
                           'master_vmos','mapping_bridge','snapshot_central','snapshot_vmos']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- 5) Kiem tra nhanh (tuy chon)
-- select tablename, rowsecurity from pg_tables where schemaname='public' order by 1;
-- select * from pg_publication_tables where pubname='supabase_realtime';
