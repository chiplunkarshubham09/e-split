import Foundation

enum SupabaseConfig {
    static var projectURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("https://"), !trimmed.contains("YOUR_") else {
            return nil
        }
        return URL(string: trimmed)
    }

    static var anonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20, !trimmed.contains("YOUR_") else {
            return nil
        }
        return trimmed
    }

    static var isEnabled: Bool {
        projectURL != nil && anonKey != nil
    }
}
