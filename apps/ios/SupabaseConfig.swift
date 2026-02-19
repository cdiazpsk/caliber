import Foundation

enum SupabaseConfig {
    static let baseURL: String = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        ?? "http://127.0.0.1:54321"

    static let anonKey: String = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        ?? "replace-with-anon-key"
}
