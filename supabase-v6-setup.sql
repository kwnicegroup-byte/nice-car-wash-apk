-- NICE CAR WASH V6 isolated schema
-- Run once in Supabase SQL Editor. Does not modify legacy POS tables or public.branches rows.
create extension if not exists pgcrypto;

create table if not exists public.v6_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.v6_branch_members (
  branch_id uuid not null references public.branches(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','staff')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key(branch_id,user_id)
);
create table if not exists public.v6_customers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  full_name text not null default '',
  phone text not null default '',
  notes text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.v6_vehicles (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  customer_id uuid references public.v6_customers(id) on delete set null,
  plate_number text not null,
  vehicle_type text not null default '',
  make_model text not null default '',
  created_at timestamptz not null default now(),
  unique(branch_id,plate_number)
);
create table if not exists public.v6_services (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  service_name text not null,
  price numeric(10,2) not null check(price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.v6_orders (
  id uuid primary key,
  branch_id uuid not null references public.branches(id),
  receipt_no text not null,
  customer_id uuid references public.v6_customers(id) on delete set null,
  vehicle_id uuid references public.v6_vehicles(id) on delete set null,
  plate_snapshot text not null default '',
  customer_snapshot text not null default '',
  employee_user_id uuid not null default auth.uid() references auth.users(id),
  payment_method text not null default 'Cash' check(payment_method in ('Cash','DuitNow QR','Card','Other')),
  subtotal numeric(10,2) not null default 0 check(subtotal >= 0),
  discount numeric(10,2) not null default 0 check(discount >= 0),
  total numeric(10,2) not null default 0 check(total >= 0),
  status text not null default 'completed' check(status in ('completed','voided')),
  device_created_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(branch_id,receipt_no)
);
create table if not exists public.v6_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.v6_orders(id) on delete cascade,
  service_id uuid references public.v6_services(id) on delete set null,
  service_name_snapshot text not null,
  unit_price numeric(10,2) not null check(unit_price >= 0),
  quantity integer not null default 1 check(quantity > 0),
  line_total numeric(10,2) not null check(line_total >= 0)
);
create table if not exists public.v6_vehicle_photos (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  vehicle_id uuid references public.v6_vehicles(id) on delete set null,
  order_id uuid references public.v6_orders(id) on delete set null,
  storage_path text not null unique,
  captured_at timestamptz not null default now(),
  uploaded_by uuid not null default auth.uid() references auth.users(id)
);
create table if not exists public.v6_audit_logs (
  id bigint generated always as identity primary key,
  branch_id uuid not null references public.branches(id),
  actor_user_id uuid not null default auth.uid() references auth.users(id),
  action text not null,
  entity text not null,
  entity_id text,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.v6_is_member(p_branch uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.v6_branch_members m where m.branch_id=p_branch and m.user_id=auth.uid() and m.active) $$;
create or replace function public.v6_is_owner(p_branch uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.v6_branch_members m where m.branch_id=p_branch and m.user_id=auth.uid() and m.active and m.role='owner') $$;

alter table public.v6_profiles enable row level security;
alter table public.v6_branch_members enable row level security;
alter table public.v6_customers enable row level security;
alter table public.v6_vehicles enable row level security;
alter table public.v6_services enable row level security;
alter table public.v6_orders enable row level security;
alter table public.v6_order_items enable row level security;
alter table public.v6_vehicle_photos enable row level security;
alter table public.v6_audit_logs enable row level security;

drop policy if exists v6_profile_read_self on public.v6_profiles;
create policy v6_profile_read_self on public.v6_profiles for select to authenticated using(user_id=auth.uid());
drop policy if exists v6_profile_update_self on public.v6_profiles;
create policy v6_profile_update_self on public.v6_profiles for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

drop policy if exists v6_members_read_self_or_owner on public.v6_branch_members;
create policy v6_members_read_self_or_owner on public.v6_branch_members for select to authenticated using(user_id=auth.uid() or public.v6_is_owner(branch_id));
drop policy if exists v6_members_owner_manage on public.v6_branch_members;
create policy v6_members_owner_manage on public.v6_branch_members for all to authenticated using(public.v6_is_owner(branch_id)) with check(public.v6_is_owner(branch_id));

drop policy if exists v6_customers_member_all on public.v6_customers;
create policy v6_customers_member_all on public.v6_customers for all to authenticated using(public.v6_is_member(branch_id)) with check(public.v6_is_member(branch_id));
drop policy if exists v6_vehicles_member_all on public.v6_vehicles;
create policy v6_vehicles_member_all on public.v6_vehicles for all to authenticated using(public.v6_is_member(branch_id)) with check(public.v6_is_member(branch_id));
drop policy if exists v6_services_member_read on public.v6_services;
create policy v6_services_member_read on public.v6_services for select to authenticated using(public.v6_is_member(branch_id));
drop policy if exists v6_services_owner_manage on public.v6_services;
create policy v6_services_owner_manage on public.v6_services for all to authenticated using(public.v6_is_owner(branch_id)) with check(public.v6_is_owner(branch_id));
drop policy if exists v6_orders_member_read on public.v6_orders;
create policy v6_orders_member_read on public.v6_orders for select to authenticated using(public.v6_is_member(branch_id));
drop policy if exists v6_orders_member_insert on public.v6_orders;
create policy v6_orders_member_insert on public.v6_orders for insert to authenticated with check(public.v6_is_member(branch_id) and employee_user_id=auth.uid());
drop policy if exists v6_orders_owner_update on public.v6_orders;
create policy v6_orders_owner_update on public.v6_orders for update to authenticated using(public.v6_is_owner(branch_id)) with check(public.v6_is_owner(branch_id));
drop policy if exists v6_items_member_read on public.v6_order_items;
create policy v6_items_member_read on public.v6_order_items for select to authenticated using(exists(select 1 from public.v6_orders o where o.id=order_id and public.v6_is_member(o.branch_id)));
drop policy if exists v6_items_member_insert on public.v6_order_items;
create policy v6_items_member_insert on public.v6_order_items for insert to authenticated with check(exists(select 1 from public.v6_orders o where o.id=order_id and public.v6_is_member(o.branch_id)));
drop policy if exists v6_photos_member_read on public.v6_vehicle_photos;
create policy v6_photos_member_read on public.v6_vehicle_photos for select to authenticated using(public.v6_is_member(branch_id));
drop policy if exists v6_photos_member_insert on public.v6_vehicle_photos;
create policy v6_photos_member_insert on public.v6_vehicle_photos for insert to authenticated with check(public.v6_is_member(branch_id) and uploaded_by=auth.uid());
drop policy if exists v6_photos_owner_delete on public.v6_vehicle_photos;
create policy v6_photos_owner_delete on public.v6_vehicle_photos for delete to authenticated using(public.v6_is_owner(branch_id));
drop policy if exists v6_audit_member_read on public.v6_audit_logs;
create policy v6_audit_member_read on public.v6_audit_logs for select to authenticated using(public.v6_is_owner(branch_id));
drop policy if exists v6_audit_member_insert on public.v6_audit_logs;
create policy v6_audit_member_insert on public.v6_audit_logs for insert to authenticated with check(public.v6_is_member(branch_id) and actor_user_id=auth.uid());

-- Bootstrap the existing owner login. The branch UUID was verified in the current project.
do $$
declare owner_id uuid; branch_uuid uuid := '2b52c65d-cbd7-405a-98d9-666fad041fce';
begin
  select id into owner_id from auth.users where lower(email)=lower('kw.nicegroup@gmail.com') limit 1;
  if owner_id is not null then
    insert into public.v6_profiles(user_id,display_name) values(owner_id,'NICE CAR WASH Owner') on conflict(user_id) do nothing;
    insert into public.v6_branch_members(branch_id,user_id,role,active) values(branch_uuid,owner_id,'owner',true)
    on conflict(branch_id,user_id) do update set role='owner',active=true;
  end if;
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('nice-car-wash-v6','nice-car-wash-v6',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
drop policy if exists v6_photo_storage_read on storage.objects;
create policy v6_photo_storage_read on storage.objects for select to authenticated
using(bucket_id='nice-car-wash-v6' and (storage.foldername(name))[1] in (select branch_id::text from public.v6_branch_members where user_id=auth.uid() and active));
drop policy if exists v6_photo_storage_insert on storage.objects;
create policy v6_photo_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='nice-car-wash-v6' and (storage.foldername(name))[1] in (select branch_id::text from public.v6_branch_members where user_id=auth.uid() and active));
drop policy if exists v6_photo_storage_delete_owner on storage.objects;
create policy v6_photo_storage_delete_owner on storage.objects for delete to authenticated
using(bucket_id='nice-car-wash-v6' and exists(select 1 from public.v6_branch_members m where m.user_id=auth.uid() and m.active and m.role='owner' and (storage.foldername(name))[1]=m.branch_id::text));

-- Seed starter wash services only if none exist for this branch.
insert into public.v6_services(branch_id,service_name,price)
select '2b52c65d-cbd7-405a-98d9-666fad041fce'::uuid, s.name, s.price
from (values ('Normal Wash',20.00::numeric),('Premium Wash',30.00::numeric)) as s(name,price)
where not exists(select 1 from public.v6_services where branch_id='2b52c65d-cbd7-405a-98d9-666fad041fce'::uuid);
