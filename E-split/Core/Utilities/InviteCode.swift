import Foundation

enum InviteCode {
    static let scheme = "esplit"
    static let host = "join"

    static func generate() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).compactMap { _ in alphabet.randomElement() })
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    static func url(for code: String) -> URL {
        URL(string: "\(scheme)://\(host)/\(normalized(code))")!
    }

    static func parse(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        if url.host?.lowercased() == host {
            let pathCode = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !pathCode.isEmpty {
                return normalized(pathCode)
            }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            if let code = items?.first(where: { $0.name == "code" })?.value {
                return normalized(code)
            }
        }
        return nil
    }
}
