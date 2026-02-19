import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var session: AuthSession?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: WorkOrderRepository
    private let sessionDefaultsKey = "auth_session"

    init(repository: WorkOrderRepository) {
        self.repository = repository
        restoreSession()
    }

    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let auth = try await repository.signIn(email: email, password: password)
            session = auth
            persistSession(auth)
        } catch {
            errorMessage = "Sign in failed. Check credentials and Supabase config."
        }
    }

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
    }

    private func persistSession(_ auth: AuthSession) {
        if let data = try? JSONEncoder().encode(auth) {
            UserDefaults.standard.set(data, forKey: sessionDefaultsKey)
        }
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionDefaultsKey),
              let auth = try? JSONDecoder().decode(AuthSession.self, from: data) else { return }
        session = auth
    }
}
