import Foundation

enum RemoteAuthSession {
    static func currentUser(
        fromSignupSession sessionUser: CurrentUser?,
        login: () async throws -> CurrentUser
    ) async throws -> CurrentUser {
        if let sessionUser {
            return sessionUser
        }
        return try await login()
    }
}
