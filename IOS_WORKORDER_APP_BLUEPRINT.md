# iOS Work Order App Blueprint

This document gives you a practical starter blueprint for building an iOS work order app in SwiftUI.

## 1) Product scope (MVP)

### Core user roles
- **Technician**: views assigned work orders, updates status, uploads photos, captures signature.
- **Dispatcher/Admin**: creates and assigns work orders, monitors progress.

### MVP feature set
1. Authentication (email/password, optional SSO later).
2. Work order list with filters (status, priority, due date).
3. Work order detail screen with:
   - customer/site info
   - checklist/tasks
   - notes
   - photo attachments
   - time tracking
4. Status workflow: `New -> Assigned -> In Progress -> Completed -> Closed`.
5. Offline-first editing + sync when online.
6. Push notifications for newly assigned or updated orders.

## 2) Suggested architecture

Use **SwiftUI + MVVM + Repository pattern**.

- `Views`: UI only.
- `ViewModels`: presentation logic + state.
- `Repositories`: abstract data source (remote/local).
- `Services`: API, auth, file uploads, notifications.
- `LocalStore`: SwiftData/Core Data cache for offline mode.

## 3) Data model starter

```swift
import Foundation

struct WorkOrder: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var status: WorkOrderStatus
    var priority: Priority
    var scheduledAt: Date?
    var dueAt: Date?
    var customerName: String
    var siteAddress: String
    var assignedTechnicianId: UUID?
    var createdAt: Date
    var updatedAt: Date
}

enum WorkOrderStatus: String, Codable, CaseIterable {
    case new = "NEW"
    case assigned = "ASSIGNED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case closed = "CLOSED"
}

enum Priority: String, Codable, CaseIterable {
    case low, medium, high, critical
}
```

## 4) Folder structure recommendation

```text
WorkOrderApp/
  App/
    WorkOrderApp.swift
  Core/
    Networking/
    Storage/
    Models/
    Utilities/
  Features/
    Auth/
    WorkOrders/
      List/
      Detail/
      Edit/
    Attachments/
    Settings/
  Shared/
    Components/
    Theme/
```

## 5) API contract (example)

- `POST /auth/login`
- `GET /work-orders?status=&assignedTo=&page=`
- `GET /work-orders/{id}`
- `PATCH /work-orders/{id}`
- `POST /work-orders/{id}/attachments`
- `POST /work-orders/{id}/status-transitions`

Tip: generate strongly typed API models from OpenAPI early.

## 6) Offline sync strategy

1. Persist last-synced records locally.
2. Queue mutations locally when offline.
3. On reconnect:
   - send queued operations FIFO
   - resolve conflicts with `updatedAt` + server version
4. Show visual badges: `Synced`, `Pending`, `Conflict`.

## 7) Security and compliance baseline

- Store tokens in Keychain.
- Enforce TLS and certificate pinning for sensitive environments.
- Redact PII from logs.
- Support remote sign-out and token revocation.

## 8) 4-week implementation roadmap

### Week 1
- Set up project skeleton, design system tokens, auth flow, basic routing.

### Week 2
- Build work order list/detail from mock API + local cache.

### Week 3
- Add edit flow, status transitions, attachments, offline queue.

### Week 4
- Push notifications, QA hardening, analytics events, TestFlight beta.

## 9) Next steps to start immediately

1. Create Xcode project using SwiftUI + SwiftData.
2. Implement login and a hardcoded list screen.
3. Integrate your existing ChatGPT-generated code in isolated feature folders.
4. Replace hardcoded data with a repository backed by API + local store.

If you want, the next iteration can include concrete Swift files for:
- authentication flow
- work order list/detail screens
- repository protocol + mock implementation
- offline mutation queue skeleton
