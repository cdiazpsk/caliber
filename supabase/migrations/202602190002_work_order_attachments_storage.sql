-- Work order photo attachments + protected Supabase Storage access

create table if not exists public.work_order_attachments (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references public.work_orders(id) on delete cascade,
  storage_path text not null unique,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.work_order_attachments enable row level security;

-- Attachment rows inherit visibility from parent work order scope.
drop policy if exists "work_order_attachments_select_by_work_order_scope" on public.work_order_attachments;
create policy "work_order_attachments_select_by_work_order_scope"
on public.work_order_attachments
for select
using (
  exists (
    select 1
    from public.work_orders wo
    where wo.id = work_order_attachments.work_order_id
      and (
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
            where m.pm_id = auth.uid() and m.tech_id = wo.technician_id
          )
        )
        or (
          exists (
            select 1 from public.profiles me
            where me.id = auth.uid() and me.role = 'tech'
          )
          and wo.technician_id = auth.uid()
        )
      )
  )
);

drop policy if exists "work_order_attachments_insert_by_work_order_scope" on public.work_order_attachments;
create policy "work_order_attachments_insert_by_work_order_scope"
on public.work_order_attachments
for insert
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.work_orders wo
    where wo.id = work_order_attachments.work_order_id
      and (
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
            where m.pm_id = auth.uid() and m.tech_id = wo.technician_id
          )
        )
        or (
          exists (
            select 1 from public.profiles me
            where me.id = auth.uid() and me.role = 'tech'
          )
          and wo.technician_id = auth.uid()
        )
      )
  )
);

-- Keep attachment mutation restricted; expand later if delete/update UX is added.
drop policy if exists "work_order_attachments_delete_admin_only" on public.work_order_attachments;
create policy "work_order_attachments_delete_admin_only"
on public.work_order_attachments
for delete
using (
  exists (
    select 1 from public.profiles me
    where me.id = auth.uid() and me.role = 'admin'
  )
);

-- Protected storage bucket for sensitive work-order photos.
insert into storage.buckets (id, name, public)
values ('workorders', 'workorders', false)
on conflict (id) do update set public = excluded.public;

-- Users can read files only when parent work order is readable.
drop policy if exists "workorders_storage_select" on storage.objects;
create policy "workorders_storage_select"
on storage.objects
for select
using (
  bucket_id = 'workorders'
  and exists (
    select 1
    from public.work_order_attachments a
    join public.work_orders wo on wo.id = a.work_order_id
    where a.storage_path = storage.objects.name
      and (
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
            select 1 from public.pm_tech_map m
            where m.pm_id = auth.uid() and m.tech_id = wo.technician_id
          )
        )
        or (
          exists (
            select 1 from public.profiles me
            where me.id = auth.uid() and me.role = 'tech'
          )
          and wo.technician_id = auth.uid()
        )
      )
  )
);

-- Upload only if file path belongs to an attachment row in-scope and created by caller.
drop policy if exists "workorders_storage_insert" on storage.objects;
create policy "workorders_storage_insert"
on storage.objects
for insert
with check (
  bucket_id = 'workorders'
  and exists (
    select 1
    from public.work_order_attachments a
    join public.work_orders wo on wo.id = a.work_order_id
    where a.storage_path = storage.objects.name
      and a.created_by = auth.uid()
      and (
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
            select 1 from public.pm_tech_map m
            where m.pm_id = auth.uid() and m.tech_id = wo.technician_id
          )
        )
        or (
          exists (
            select 1 from public.profiles me
            where me.id = auth.uid() and me.role = 'tech'
          )
          and wo.technician_id = auth.uid()
        )
      )
  )
);
