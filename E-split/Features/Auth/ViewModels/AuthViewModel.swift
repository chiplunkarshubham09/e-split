import Foundation

@Observable
final class AuthViewModel {
    var name = ""
    var email = ""
    var password = ""
    var errorMessage: String?
    var isWorking = false
    var isRegistering = false

    private let auth: AuthRepositoryProtocol

    init(auth: AuthRepositoryProtocol) {
        self.auth = auth
    }

    func submit() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            if isRegistering {
                try await auth.register(name: name, email: email, password: password)
            } else {
                try await auth.login(email: email, password: password)
            }
            errorMessage = nil
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return false
        }
    }
}
