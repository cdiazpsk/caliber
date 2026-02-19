-- Work orders schema and row-level security

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'pm', 'tech')),
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.pm_tech_map (
  pm_id uuid not null references public.profiles(id) on delete cascade,
  tech_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (pm_id, tech_id),
  constraint pm_tech_map_distinct_users check (pm_id <> tech_id)
);

create table if not exists public.work_orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  title text not null,
  description text,
  status text not null default 'new',
  priority text not null default 'medium',
  property_id uuid,
  technician_id uuid not null references public.profiles(id),
  created_by uuid not null references public.profiles(id)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_work_orders_set_updated_at on public.work_orders;
create trigger trg_work_orders_set_updated_at
before update on public.work_orders
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.pm_tech_map enable row level security;
alter table public.work_orders enable row level security;

-- Profiles policies (prevent broad user enumeration)
drop policy if exists "profiles_select_self_admin_or_pm_scope" on public.profiles;
create policy "profiles_select_self_admin_or_pm_scope"
on public.profiles
for select
using (
  id = auth.uid()
  or exists (
    select 1
    from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
  or (
    exists (
      select 1
      from public.profiles me
      where me.id = auth.uid() and me.role = 'pm'
    )
    and exists (
      select 1
      from public.pm_tech_map m
      where m.pm_id = auth.uid() and m.tech_id = profiles.id
    )
  )
);

drop policy if exists "profiles_admin_manage" on public.profiles;
create policy "profiles_admin_manage"
on public.profiles
for all
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
);

-- PM/Tech map policies (no broad enumeration)
drop policy if exists "pm_tech_map_select_limited" on public.pm_tech_map;
create policy "pm_tech_map_select_limited"
on public.pm_tech_map
for select
using (
  pm_id = auth.uid()
  or tech_id = auth.uid()
  or exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
);

drop policy if exists "pm_tech_map_admin_manage" on public.pm_tech_map;
create policy "pm_tech_map_admin_manage"
on public.pm_tech_map
for all
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
);

-- Work order SELECT
drop policy if exists "work_orders_select_by_role_scope" on public.work_orders;
create policy "work_orders_select_by_role_scope"
on public.work_orders
for select
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'pm'
    )
    and exists (
      select 1
      from public.pm_tech_map m
      where m.pm_id = auth.uid() and m.tech_id = work_orders.technician_id
    )
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'tech'
    )
    and work_orders.technician_id = auth.uid()
  )
);

-- Work order INSERT
drop policy if exists "work_orders_insert_by_role_scope" on public.work_orders;
create policy "work_orders_insert_by_role_scope"
on public.work_orders
for insert
with check (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'pm'
    )
    and exists (
      select 1
      from public.pm_tech_map m
      where m.pm_id = auth.uid() and m.tech_id = work_orders.technician_id
    )
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'tech'
    )
    and work_orders.technician_id = auth.uid()
  )
);

-- Work order UPDATE
drop policy if exists "work_orders_update_by_role_scope" on public.work_orders;
create policy "work_orders_update_by_role_scope"
on public.work_orders
for update
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'pm'
    )
    and exists (
      select 1
      from public.pm_tech_map m
      where m.pm_id = auth.uid() and m.tech_id = work_orders.technician_id
    )
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'tech'
    )
    and work_orders.technician_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'pm'
    )
    and exists (
      select 1
      from public.pm_tech_map m
      where m.pm_id = auth.uid() and m.tech_id = work_orders.technician_id
    )
  )
  or (
    exists (
      select 1 from public.profiles me
      where me.id = auth.uid() and me.role = 'tech'
    )
    and work_orders.technician_id = auth.uid()
  )
);

-- Work order DELETE (admin only)
drop policy if exists "work_orders_delete_admin_only" on public.work_orders;
create policy "work_orders_delete_admin_only"
on public.work_orders
for delete
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
);
