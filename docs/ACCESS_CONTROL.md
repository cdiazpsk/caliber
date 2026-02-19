# Access Control (Stub)

This document is the initial access-control stub for the planned work order platform.

## Role model (initial)
- **Technician**
  - View assigned work orders.
  - Update status, notes, attachments, and completion metadata.
- **Dispatcher/Admin**
  - Create/assign/reassign work orders.
  - View all active orders and operational dashboards.
- **Org Owner (future)**
  - Tenant-level settings, billing, and user management.

## Enforcement layers
1. **Supabase Auth** for identity.
2. **Row Level Security (RLS)** in `/supabase` for data access control.
3. **Application checks** in iOS/web to shape UX and prevent invalid actions.

## Initial policy intent
- Technicians can only read/update work orders assigned to them (or visible to their team, if configured).
- Dispatchers/Admins can read all tenant work orders and manage assignment.
- Cross-tenant access is always denied.

## Secrets and credentials
- Never store production credentials in repo.
- Keep local secrets in untracked env files.
- Commit only redacted examples (e.g., `.env.example`, `*.example.xcconfig`).

## To be defined next
- Exact JWT claim mapping to app roles.
- Fine-grained permissions matrix per resource/action.
- Audit logging requirements (who changed status/assignment and when).
