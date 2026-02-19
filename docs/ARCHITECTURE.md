# Architecture (Stub)

This document is the initial architecture stub for the planned monorepo.

## Planned monorepo layout

```text
/apps
  /ios        # SwiftUI iOS app (Xcode project/workspace)
  /web        # Next.js App Router frontend
/supabase     # SQL migrations, seed scripts, RLS policies
/docs         # Product/engineering docs
```

## High-level direction
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
