# Architecture

This document is the architecture baseline for the planned monorepo.
# Architecture (Stub)

This document is the initial architecture stub for the planned monorepo.

## Planned monorepo layout

```text
/apps
  /ios        # SwiftUI iOS app (Xcode project/workspace)
  /web        # Next.js App Router frontend
/supabase     # SQL migrations, seed scripts, RLS policies, storage policy model
/supabase     # SQL migrations, seed scripts, RLS policies
/docs         # Product/engineering docs
```

## High-level direction
- **iOS app**: field technician/work order experience, offline-friendly updates.
- **Web app**: admin/dispatcher workflows and reporting.
- **Supabase**: auth, Postgres, row-level security, and private storage for sensitive artifacts.

## Data and access boundaries
- `/supabase` is the source of truth for:
  - relational schema (`work_orders`, `profiles`, `pm_tech_map`, `work_order_attachments`)
  - role-based RLS (admin/pm/tech)
  - storage policies for bucket-level object access
- `/apps/web` and `/apps/ios` must query only scoped rows and render returned data. Role logic is not duplicated client-side.

## Attachment architecture
- Photos are modeled with `work_order_attachments` rows referencing:
  - `work_order_id`
  - `storage_path`
  - `created_by`
- Binary files are stored in Supabase Storage bucket `workorders` configured as **private** (`public = false`).
- Access to attachment rows and objects is enforced at the DB/storage policy layer by validating access to the parent work order.
- Clients use signed URLs for temporary image access in galleries/detail views.

## Security notes
- Sensitive photos must never use a public bucket.
- Never rely on client-side filtering for authorization; enforce at RLS/storage policies.
- Keep secrets out of source control (`.env.local`, xcconfig secrets only in local/untracked files).

## To be defined next
- Domain ownership per bounded context.
- API type generation and validation strategy.
- Observability and audit logging for attachment upload/update events.
- **iOS app**: field technician/work order experience.
- **Web app**: admin/dispatcher workflows and reporting.
- **Supabase**: auth, Postgres, row-level security, and storage metadata.

## Initial boundaries
- `/apps/ios`: UI, local state, API clients, offline queue logic.
- `/apps/web`: server/client components, dashboard/admin flows.
- `/supabase`: schema source-of-truth, policy definitions, seed data.

## To be defined next
- Domain model and ownership per bounded context.
- API contract strategy (REST/typed client generation).
- Offline sync/conflict strategy between iOS and backend.
- Observability/logging and release strategy.
