-- Seed users + profiles + mapping + sample work orders
-- Uses deterministic UUIDs for repeatable local development.

create extension if not exists pgcrypto;

-- 1 admin, 1 pm, 2 techs in auth.users (required by profiles FK)
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@example.com',
    crypt('changeme123!', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Admin User"}'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'pm@example.com',
    crypt('changeme123!', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"PM User"}'
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'tech1@example.com',
    crypt('changeme123!', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Tech One"}'
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'tech2@example.com',
    crypt('changeme123!', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Tech Two"}'
  )
on conflict (id) do nothing;

insert into public.profiles (id, role, full_name)
values
  ('11111111-1111-1111-1111-111111111111', 'admin', 'Admin User'),
  ('22222222-2222-2222-2222-222222222222', 'pm', 'PM User'),
  ('33333333-3333-3333-3333-333333333333', 'tech', 'Tech One'),
  ('44444444-4444-4444-4444-444444444444', 'tech', 'Tech Two')
on conflict (id) do update set role = excluded.role, full_name = excluded.full_name;

insert into public.pm_tech_map (pm_id, tech_id)
values
  ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'),
  ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444')
on conflict do nothing;

insert into public.work_orders (id, title, description, status, priority, property_id, technician_id, created_by)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'HVAC inspection - Unit A',
    'Perform seasonal inspection and replace filters.',
    'assigned',
    'medium',
    null,
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    'Water heater leak',
    'Diagnose and repair leak in mechanical room.',
    'in_progress',
    'high',
    null,
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'Parking lot lighting outage',
    'Replace failed ballast and test fixtures.',
    'new',
    'critical',
    null,
    '44444444-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222'
  )
on conflict (id) do nothing;

-- Sample attachment metadata rows (object files should be uploaded to storage bucket `workorders`)
insert into public.work_order_attachments (id, work_order_id, storage_path, created_by)
values
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1/sample-photo-1.jpg',
    '33333333-3333-3333-3333-333333333333'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3/sample-photo-2.jpg',
    '44444444-4444-4444-4444-444444444444'
  )
on conflict (id) do nothing;
