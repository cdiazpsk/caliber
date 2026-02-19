import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum RepositoryError: Error {
    case invalidURL
    case unauthorized
    case httpError(Int)
    case decodeError
}

private struct SignedURLResponse: Codable {
    let signedURL: String

    enum CodingKeys: String, CodingKey {
        case signedURL = "signedURL"
    }
}

private struct UserResponse: Codable {
    struct User: Codable {
        let id: UUID
    }
    let user: User
}

final class WorkOrderRepository {
    private let baseURL: String
    private let anonKey: String
    private let session: URLSession

    init(baseURL: String = SupabaseConfig.baseURL, anonKey: String = SupabaseConfig.anonKey, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        guard let auth = try? decoder.decode(AuthSession.self, from: data) else {
            throw RepositoryError.decodeError
        }
        return auth
    }

    func fetchWorkOrders(accessToken: String) async throws -> [WorkOrder] {
        let select = "id,created_at,updated_at,title,description,status,priority,property_id,technician_id,created_by"
        guard let url = URL(string: "\(baseURL)/rest/v1/work_orders?select=\(select)&order=updated_at.desc") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let workOrders = try? decoder.decode([WorkOrder].self, from: data) else {
            throw RepositoryError.decodeError
        }
        return workOrders
    }

    func updateWorkOrder(accessToken: String, workOrderId: UUID, status: String, notes: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/work_orders?id=eq.\(workOrderId.uuidString)") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "status": status,
            "description": notes
        ])

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }
    }

    func fetchAttachments(accessToken: String, workOrderId: UUID) async throws -> [WorkOrderAttachment] {
        let select = "id,work_order_id,storage_path,created_by,created_at"
        guard let url = URL(string: "\(baseURL)/rest/v1/work_order_attachments?work_order_id=eq.\(workOrderId.uuidString)&select=\(select)&order=created_at.desc") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var attachments = try? decoder.decode([WorkOrderAttachment].self, from: data) else {
            throw RepositoryError.decodeError
        }

        for i in attachments.indices {
            attachments[i].signedUrl = try? await signedURL(accessToken: accessToken, storagePath: attachments[i].storagePath)
        }

        return attachments
    }

    func uploadAttachment(accessToken: String, workOrderId: UUID, imageData: Data, contentType: String = "image/jpeg") async throws {
        let userId = try await fetchCurrentUserId(accessToken: accessToken)
        let objectPath = "\(workOrderId.uuidString)/\(UUID().uuidString).jpg"

        // Insert metadata row first (enforced by table RLS).
        guard let rowURL = URL(string: "\(baseURL)/rest/v1/work_order_attachments") else {
            throw RepositoryError.invalidURL
        }

        var rowRequest = URLRequest(url: rowURL)
        rowRequest.httpMethod = "POST"
        rowRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rowRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        rowRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        rowRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        rowRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "work_order_id": workOrderId.uuidString,
            "storage_path": objectPath,
            "created_by": userId.uuidString
        ])

        let (_, rowResponse) = try await session.data(for: rowRequest)
        guard let rowHTTP = rowResponse as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if rowHTTP.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(rowHTTP.statusCode) else { throw RepositoryError.httpError(rowHTTP.statusCode) }

        // Upload object to private bucket (storage RLS checks path against metadata row).
        guard let objectURL = URL(string: "\(baseURL)/storage/v1/object/workorders/\(objectPath)") else {
            throw RepositoryError.invalidURL
        }

        var uploadRequest = URLRequest(url: objectURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("false", forHTTPHeaderField: "x-upsert")
        uploadRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        uploadRequest.httpBody = imageData

        let (_, objectResponse) = try await session.data(for: uploadRequest)
        guard let objectHTTP = objectResponse as? HTTPURLResponse else { throw RepositoryError.decodeError }

        if !(200...299).contains(objectHTTP.statusCode) {
            try? await deleteAttachmentRow(accessToken: accessToken, storagePath: objectPath)
            throw RepositoryError.httpError(objectHTTP.statusCode)
        }
    }

    private func fetchCurrentUserId(accessToken: String) async throws -> UUID {
        guard let url = URL(string: "\(baseURL)/auth/v1/user") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        guard let user = try? decoder.decode(UserResponse.self, from: data) else {
            throw RepositoryError.decodeError
        }
        return user.user.id
    }

    private func signedURL(accessToken: String, storagePath: String) async throws -> URL {
        guard let encodedPath = storagePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/storage/v1/object/sign/workorders/\(encodedPath)") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": 3600])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.decodeError }
        if http.statusCode == 401 { throw RepositoryError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw RepositoryError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(SignedURLResponse.self, from: data) else {
            throw RepositoryError.decodeError
        }

        guard let signed = URL(string: "\(baseURL)\(payload.signedURL)") else {
            throw RepositoryError.decodeError
        }

        return signed
    }

    private func deleteAttachmentRow(accessToken: String, storagePath: String) async throws {
        guard let encoded = storagePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/rest/v1/work_order_attachments?storage_path=eq.\(encoded)") else {
            throw RepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        _ = try await session.data(for: request)
    }
}
