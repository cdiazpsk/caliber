import Foundation

@MainActor
final class WorkOrdersViewModel: ObservableObject {
    @Published var workOrders: [WorkOrder] = []
    @Published var pendingQueue: [PendingWorkOrderUpdate] = []
    @Published var attachmentsByWorkOrder: [UUID: [WorkOrderAttachment]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: WorkOrderRepository
    private let queueStore: SyncQueueStore

    init(repository: WorkOrderRepository, queueStore: SyncQueueStore = SyncQueueStore()) {
        self.repository = repository
        self.queueStore = queueStore
        self.pendingQueue = queueStore.load()
    }

    func loadWorkOrders(accessToken: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            workOrders = try await repository.fetchWorkOrders(accessToken: accessToken)
        } catch {
            errorMessage = "Could not load work orders."
        }
    }

    func loadAttachments(accessToken: String, workOrderId: UUID) async {
        do {
            let items = try await repository.fetchAttachments(accessToken: accessToken, workOrderId: workOrderId)
            attachmentsByWorkOrder[workOrderId] = items
        } catch {
            errorMessage = "Could not load photos."
        }
    }

    func uploadAttachment(accessToken: String, workOrderId: UUID, imageData: Data) async {
        do {
            try await repository.uploadAttachment(accessToken: accessToken, workOrderId: workOrderId, imageData: imageData)
            await loadAttachments(accessToken: accessToken, workOrderId: workOrderId)
        } catch {
            errorMessage = "Photo upload failed."
        }
    }

    func updateWorkOrder(
        accessToken: String,
        workOrderId: UUID,
        status: String,
        notes: String,
        isOnline: Bool
    ) async {
        if isOnline {
            do {
                try await repository.updateWorkOrder(
                    accessToken: accessToken,
                    workOrderId: workOrderId,
                    status: status,
                    notes: notes
                )
                removePending(for: workOrderId)
                await loadWorkOrders(accessToken: accessToken)
                return
            } catch {
                // Fall back to queue on transient/offline failures.
            }
        }

        enqueue(workOrderId: workOrderId, status: status, notes: notes)
        applyLocalPendingState(workOrderId: workOrderId, status: status, notes: notes)
    }

    func flushQueueIfPossible(accessToken: String, isOnline: Bool) async {
        guard isOnline else { return }
        let queue = pendingQueue
        guard !queue.isEmpty else { return }

        var remaining: [PendingWorkOrderUpdate] = []

        for item in queue {
            do {
                try await repository.updateWorkOrder(
                    accessToken: accessToken,
                    workOrderId: item.workOrderId,
                    status: item.status,
                    notes: item.notes
                )
            } catch {
                remaining.append(item)
            }
        }

        pendingQueue = remaining
        queueStore.save(remaining)
        await loadWorkOrders(accessToken: accessToken)
    }

    func isPending(workOrderId: UUID) -> Bool {
        pendingQueue.contains { $0.workOrderId == workOrderId }
    }

    func pendingUpdate(for workOrderId: UUID) -> PendingWorkOrderUpdate? {
        pendingQueue.last(where: { $0.workOrderId == workOrderId })
    }

    private func enqueue(workOrderId: UUID, status: String, notes: String) {
        let item = PendingWorkOrderUpdate(
            id: UUID(),
            workOrderId: workOrderId,
            status: status,
            notes: notes,
            enqueuedAt: Date()
        )
        pendingQueue.removeAll(where: { $0.workOrderId == workOrderId })
        pendingQueue.append(item)
        queueStore.save(pendingQueue)
    }

    private func removePending(for workOrderId: UUID) {
        pendingQueue.removeAll(where: { $0.workOrderId == workOrderId })
        queueStore.save(pendingQueue)
    }

    private func applyLocalPendingState(workOrderId: UUID, status: String, notes: String) {
        guard let index = workOrders.firstIndex(where: { $0.id == workOrderId }) else { return }
        let existing = workOrders[index]
        let patched = WorkOrder(
            id: existing.id,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            title: existing.title,
            description: notes,
            status: status,
            priority: existing.priority,
            propertyId: existing.propertyId,
            technicianId: existing.technicianId,
            createdBy: existing.createdBy
        )
        workOrders[index] = patched
    }
}
