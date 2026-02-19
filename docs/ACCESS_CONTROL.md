# Access Control

This document defines role-based data access for the work-order platform.

## Threat model notes
- **All authorization is enforced in PostgreSQL RLS policies.**
- Client-side checks are UX-only and are never considered sufficient for security.
- Assume API clients can be modified by end users; the database must deny out-of-scope access regardless of client behavior.

## Roles
- **admin**
  - Read/write all work orders.
  - Manage profile records and PM-to-technician mappings.
- **pm**
  - Read work orders assigned to technicians mapped to them in `pm_tech_map`.
  - Create/update work orders within mapped technician scope.
- **tech**
  - Read/update only work orders where `work_orders.technician_id = auth.uid()`.
  - Can insert only work orders assigned to themselves.

## Tables and policy intent

### `profiles`
- Contains user role metadata (`admin`, `pm`, `tech`).
- RLS enabled.
- `SELECT` allowed for:
  - self (`id = auth.uid()`),
  - admins (all rows),
  - PMs only for mapped technicians.
- `INSERT/UPDATE/DELETE` restricted to admins.

### `pm_tech_map`
- Defines PM visibility scope over technicians.
- RLS enabled.
- `SELECT` allowed for:
  - admins,
  - PMs for rows where `pm_id = auth.uid()`,
  - technicians for rows where `tech_id = auth.uid()`.
- `INSERT/UPDATE/DELETE` restricted to admins.


### `work_order_attachments` + storage `workorders` bucket
- Attachment metadata in `work_order_attachments` inherits parent work-order scope.
- `SELECT`/`INSERT` on attachments is allowed only when caller can access the parent `work_orders` row; insert also requires `created_by = auth.uid()`.
- Storage bucket `workorders` is private (`public = false`).
- Storage object `SELECT`/`INSERT` policies validate path membership against `work_order_attachments` and parent work-order scope.

### `work_orders`
- Main work order records.
- RLS enabled.
- `SELECT`:
  - admin: all rows,
  - pm: rows where `technician_id` is mapped to the PM,
  - tech: rows where `technician_id = auth.uid()`.
- `INSERT`:
  - admin: any row,
  - pm: only for mapped technicians,
  - tech: only when assigning to self.
- `UPDATE`:
  - admin: any row,
  - pm: only mapped technician scope,
  - tech: only own rows.
- `DELETE`:
  - admin only.

## Example outcomes
- A tech attempting `SELECT * FROM work_orders` receives only their own rows.
- A PM cannot read or update work orders assigned to an unmapped technician.
- An admin can perform full lifecycle operations across all work orders.
- A non-admin user cannot enumerate all profiles or all PM-tech mappings.

## Operational guidance
- Keep role assignment in `profiles` synchronized with `auth.users` identity.
- Treat seed/demo credentials as local-only; rotate or remove for production environments.
- Add integration tests for RLS paths whenever policy logic changes.
