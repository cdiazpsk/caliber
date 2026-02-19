# Caliber Web (`/apps/web`)

Next.js App Router frontend for work orders with Supabase Auth + RLS-backed data access.

## Features implemented
- Sign-in page using Supabase Auth password flow.
- Session-aware route protection via `middleware.ts`.
- Work orders list page with server-side Supabase queries and filters:
  - status
  - priority
  - property
  - technician (visible only for `admin`/`pm` users)
- Work order detail page to view/update status and notes.
- Work order photo upload + gallery via Supabase Storage bucket `workorders` (private).
- Admin-only PM→Tech mapping management page (`/admin/assignments`) with create/delete actions.

> Security rule: Never fetch all work orders and filter on client. Query Supabase directly and rely on RLS.

## Environment variables
Create `apps/web/.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

See `.env.example` for keys.

## Local development
From repo root:

```bash
cd apps/web
npm install
npm run dev
```

Open http://localhost:3000.

## Build / smoke check

```bash
npm run smoke
```

`smoke` currently runs `next build` as a minimal build verification.
