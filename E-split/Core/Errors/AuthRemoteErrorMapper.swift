import Foundation
import Auth

enum AuthRemoteErrorMapper {
    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let authError = error as? AuthError {
            if authError.errorCode == .emailNotConfirmed {
                return .emailNotConfirmed
            }
            if authError.errorCode == .userAlreadyExists {
                return .emailAlreadyRegistered
            }
            if authError.errorCode == .providerDisabled {
                return .emailAuthDisabled
            }
            return map(text: authError.message + " " + authError.errorCode.rawValue)
        }

        return map(text: [
            error.localizedDescription,
            String(describing: error)
        ].joined(separator: " "))
    }

    static func map(text raw: String) -> AppError {
        let text = raw.lowercased()
        if text.contains("already registered")
            || text.contains("user already registered")
            || text.contains("user_already_exists") {
            return .emailAlreadyRegistered
        }
        if text.contains("confirmation email") || text.contains("error sending confirmation") {
            return .confirmationEmailFailed
        }
        if text.contains("email_not_confirmed")
            || text.contains("email not confirmed")
            || text.contains("not confirmed") {
            return .emailNotConfirmed
        }
        if text.contains("email_provider_disabled")
            || text.contains("email signups are disabled")
            || text.contains("email logins are disabled")
            || text.contains("provider_disabled") {
            return .emailAuthDisabled
        }
        if text.contains("no_profile") || text.contains("memberneedsaccount") {
            return .memberNeedsAccount
        }
        if text.contains("invalid login") || text.contains("invalid credentials") {
            return .invalidCredentials
        }
        return .saveFailed
    }
}
