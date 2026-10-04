import CryptoKit
import Foundation

enum PasswordHasher {
    static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    static func hash(password: String, salt: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: salt)
        hasher.update(data: Data(password.utf8))
        return Data(hasher.finalize())
    }

    static func matches(password: String, salt: Data, hash: Data) -> Bool {
        self.hash(password: password, salt: salt) == hash
    }
}

enum EmailValidator {
    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ raw: String) -> Bool {
        let email = normalized(raw)
        return email.contains("@") && email.contains(".") && email.count >= 5
    }
}
