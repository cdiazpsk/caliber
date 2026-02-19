import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var authVM: AuthViewModel
    @StateObject private var workOrdersVM: WorkOrdersViewModel

    init(repository: WorkOrderRepository = WorkOrderRepository()) {
        _authVM = StateObject(wrappedValue: AuthViewModel(repository: repository))
        _workOrdersVM = StateObject(wrappedValue: WorkOrdersViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if authVM.session == nil {
                SignInView(authVM: authVM)
            } else {
                WorkOrdersRootView(
                    authVM: authVM,
                    workOrdersVM: workOrdersVM,
                    networkMonitor: networkMonitor
                )
            }
        }
    }
}

private struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign in") {
                    TextField("Email", text: $authVM.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $authVM.password)
                    Button(authVM.isLoading ? "Signing in..." : "Sign in") {
                        Task { await authVM.signIn() }
                    }
                    .disabled(authVM.isLoading)
                }

                if let error = authVM.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Work Orders")
        }
    }
}

private struct WorkOrdersRootView: View {
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var workOrdersVM: WorkOrdersViewModel
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        NavigationStack {
            List(workOrdersVM.workOrders) { order in
                NavigationLink {
                    WorkOrderDetailView(
                        workOrder: order,
                        attachments: workOrdersVM.attachmentsByWorkOrder[order.id] ?? [],
                        isPending: workOrdersVM.isPending(workOrderId: order.id),
                        pendingUpdate: workOrdersVM.pendingUpdate(for: order.id),
                        accessToken: authVM.session?.accessToken,
                        workOrdersVM: workOrdersVM,
                        isOnline: networkMonitor.isOnline
                    ) { status, notes in
                        guard let token = authVM.session?.accessToken else { return }
                        await workOrdersVM.updateWorkOrder(
                            accessToken: token,
                            workOrderId: order.id,
                            status: status,
                            notes: notes,
                            isOnline: networkMonitor.isOnline
                        )
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.title).font(.headline)
                        Text("Status: \(order.status) • Priority: \(order.priority)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if workOrdersVM.isPending(workOrderId: order.id) {
                            Text("Pending Sync")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .refreshable {
                await refreshAndSync()
            }
            .task {
                await refreshAndSync()
            }
            .onChange(of: networkMonitor.isOnline) { _, _ in
                Task { await refreshAndSync() }
            }
            .navigationTitle("Work Orders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(networkMonitor.isOnline ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(networkMonitor.isOnline ? .green : .orange)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { authVM.signOut() }
                }
            }
        }
    }

    private func refreshAndSync() async {
        guard let token = authVM.session?.accessToken else { return }
        await workOrdersVM.flushQueueIfPossible(accessToken: token, isOnline: networkMonitor.isOnline)
        await workOrdersVM.loadWorkOrders(accessToken: token)
    }
}

private struct WorkOrderDetailView: View {
    let workOrder: WorkOrder
    let attachments: [WorkOrderAttachment]
    let isPending: Bool
    let pendingUpdate: PendingWorkOrderUpdate?
    let accessToken: String?
    @ObservedObject var workOrdersVM: WorkOrdersViewModel
    let isOnline: Bool
    let onSave: (_ status: String, _ notes: String) async -> Void

    @State private var status: String
    @State private var notes: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    init(
        workOrder: WorkOrder,
        attachments: [WorkOrderAttachment],
        isPending: Bool,
        pendingUpdate: PendingWorkOrderUpdate?,
        accessToken: String?,
        workOrdersVM: WorkOrdersViewModel,
        isOnline: Bool,
        onSave: @escaping (_ status: String, _ notes: String) async -> Void
    ) {
        self.workOrder = workOrder
        self.attachments = attachments
        self.isPending = isPending
        self.pendingUpdate = pendingUpdate
        self.accessToken = accessToken
        self.workOrdersVM = workOrdersVM
        self.isOnline = isOnline
        self.onSave = onSave
        _status = State(initialValue: pendingUpdate?.status ?? workOrder.status)
        _notes = State(initialValue: pendingUpdate?.notes ?? workOrder.description ?? "")
    }

    var body: some View {
        Form {
            Section("Details") {
                Text(workOrder.title)
                Text("Priority: \(workOrder.priority)")
                Text("Technician: \(workOrder.technicianId.uuidString)")
                if isPending {
                    Text("Pending Sync")
                        .foregroundStyle(.orange)
                }
            }

            Section("Update") {
                Picker("Status", selection: $status) {
                    Text("new").tag("new")
                    Text("assigned").tag("assigned")
                    Text("in_progress").tag("in_progress")
                    Text("completed").tag("completed")
                    Text("closed").tag("closed")
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 120)

                Button("Save") {
                    Task { await onSave(status, notes) }
                }
            }

            Section("Photos") {
                if !isOnline {
                    Text("Photo upload requires connectivity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Select Photo")
                }

                Button("Capture Photo") {
                    showCamera = true
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            if let url = attachment.signedUrl {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView().frame(width: 120, height: 120)
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipped()
                                            .cornerRadius(8)
                                    case .failure:
                                        Color.gray.frame(width: 120, height: 120)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Work Order")
        .task {
            guard let token = accessToken else { return }
            await workOrdersVM.loadAttachments(accessToken: token, workOrderId: workOrder.id)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                guard let token = accessToken,
                      let data = try? await item.loadTransferable(type: Data.self) else { return }
                await workOrdersVM.uploadAttachment(accessToken: token, workOrderId: workOrder.id, imageData: data)
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { imageData in
                guard let token = accessToken else { return }
                Task {
                    await workOrdersVM.uploadAttachment(accessToken: token, workOrderId: workOrder.id, imageData: imageData)
                }
            }
        }
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageData: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageData: onImageData, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageData: (Data) -> Void
        let dismiss: DismissAction

        init(onImageData: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onImageData = onImageData
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                onImageData(data)
            }
            dismiss()
        }
    }
}
