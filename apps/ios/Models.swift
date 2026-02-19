import Foundation

struct WorkOrder: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date?
    let updatedAt: Date?
    let title: String
    let description: String?
    let status: String
    let priority: String
    let propertyId: UUID?
    let technicianId: UUID
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title
        case description
        case status
        case priority
        case propertyId = "property_id"
        case technicianId = "technician_id"
        case createdBy = "created_by"
    }
}

struct WorkOrderAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    let workOrderId: UUID
    let storagePath: String
    let createdBy: UUID
    let createdAt: Date
    var signedUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId = "work_order_id"
        case storagePath = "storage_path"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct PendingWorkOrderUpdate: Identifiable, Codable, Hashable {
    let id: UUID
    let workOrderId: UUID
    let status: String
    let notes: String
    let enqueuedAt: Date
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}
