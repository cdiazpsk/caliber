# iOS App (`/apps/ios`)

Minimal SwiftUI work-orders client that uses Supabase Auth + PostgREST and relies on database RLS for authorization.

## Features implemented
- Email/password sign-in with Supabase Auth.
- Work Orders list fetched from Supabase REST (RLS-scoped rows only).
- Work Order detail with status + notes updates.
- Photo attachments upload + gallery using Supabase Storage (private bucket).
- Offline-friendly updates:
  - Failed/offline updates are queued persistently.
  - Queue retries when connectivity returns.
  - Photo uploads require online connection and are retried manually from detail.
  - UI shows `Pending Sync` for queued updates.

## Environment setup
The app expects these values in `SupabaseConfig.swift` (or inject from an xcconfig/plist in a real app):

- `SUPABASE_URL` (e.g. `http://127.0.0.1:54321`)
- `SUPABASE_ANON_KEY`

Current scaffold reads from process environment first, then falls back to placeholders.

If you prefer env-style templates for local tooling, copy `apps/ios/.env.example` to a local untracked `.env` file used by your scripts.

## Build
1. Create/open an Xcode SwiftUI project under `/apps/ios` and add these files.
2. Set iOS target to 17+ (for modern SwiftUI + async/await ergonomics).
3. Build in Xcode, or via CLI (replace placeholders):

```bash
xcodebuild -project apps/ios/<Project>.xcodeproj \
  -scheme <Scheme> \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Notes
- Role logic remains server-side via Supabase RLS; the app never broad-fetches then filters by role.
- For production, store session tokens in Keychain and add stronger error/retry telemetry.
