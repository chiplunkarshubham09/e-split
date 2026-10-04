import Foundation

protocol CurrentUserProviding: AnyObject {
    var currentUser: CurrentUser { get }
    func updateName(_ name: String)
}

protocol AuthRepositoryProtocol: CurrentUserProviding {
    var isLoggedIn: Bool { get }
    func register(name: String, email: String, password: String) async throws
    func login(email: String, password: String) async throws
    func logout()
}

@Observable
final class AuthRepository: AuthRepositoryProtocol {
    private enum Keys {
        static let sessionID = "auth.sessionUserId"
        static let sessionName = "auth.sessionName"
        static let sessionEmail = "auth.sessionEmail"
    }

    private let local: LocalExpenseDataSource
    private let remote: RemoteBackend?
    private let defaults: UserDefaults
    private var session: CurrentUser?

    var isLoggedIn: Bool { session != nil }

    var currentUser: CurrentUser {
        session ?? CurrentUser(id: UUID(), name: "", email: "")
    }

    init(
        local: LocalExpenseDataSource,
        remote: RemoteBackend? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.local = local
        self.remote = remote
        self.defaults = defaults
        restoreCachedSession()
        if remote != nil {
            Task { await restoreRemoteSession() }
        }
    }

    func register(name: String, email: String, password: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AppError.memberNameRequired }
        let normalizedEmail = EmailValidator.normalized(email)
        guard !normalizedEmail.isEmpty else { throw AppError.emailRequired }
        guard EmailValidator.isValid(normalizedEmail) else { throw AppError.invalidEmail }

        if let remote {
            do {
                let user = try await remote.register(name: trimmedName, email: normalizedEmail, password: password)
                setSession(user)
                return
            } catch {
                throw AuthRemoteErrorMapper.map(error)
            }
        }

        if try local.fetchAccount(email: normalizedEmail) != nil {
            throw AppError.emailAlreadyRegistered
        }
        let salt = PasswordHasher.makeSalt()
        let account = StoredAccount(
            id: UUID(),
            name: trimmedName,
            email: normalizedEmail,
            passwordHash: PasswordHasher.hash(password: password, salt: salt),
            passwordSalt: salt,
            createdAt: .now
        )
        try local.saveAccount(account)
        setSession(CurrentUser(id: account.id, name: account.name, email: account.email))
    }

    func login(email: String, password: String) async throws {
        let normalizedEmail = EmailValidator.normalized(email)
        guard !normalizedEmail.isEmpty else { throw AppError.emailRequired }

        if let remote {
            do {
                let user = try await remote.login(email: normalizedEmail, password: password)
                setSession(user)
                return
            } catch {
                let mapped = AuthRemoteErrorMapper.map(error)
                throw mapped == .saveFailed ? AppError.invalidCredentials : mapped
            }
        }

        guard let account = try local.fetchAccount(email: normalizedEmail) else {
            throw AppError.invalidCredentials
        }
        guard PasswordHasher.matches(password: password, salt: account.passwordSalt, hash: account.passwordHash) else {
            throw AppError.invalidCredentials
        }
        setSession(CurrentUser(id: account.id, name: account.name, email: account.email))
    }

    func logout() {
        session = nil
        defaults.removeObject(forKey: Keys.sessionID)
        defaults.removeObject(forKey: Keys.sessionName)
        defaults.removeObject(forKey: Keys.sessionEmail)
        if let remote {
            Task { await remote.logout() }
        }
    }

    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var user = session else { return }
        user.name = trimmed
        session = user
        defaults.set(trimmed, forKey: Keys.sessionName)
        if var account = try? local.fetchAccount(id: user.id) {
            account.name = trimmed
            try? local.saveAccount(account)
        }
        propagateNameToMemberships(user)
        if let remote {
            Task { try? await remote.updateProfileName(trimmed, userId: user.id) }
        }
    }

    private func restoreCachedSession() {
        guard let idString = defaults.string(forKey: Keys.sessionID),
              let id = UUID(uuidString: idString) else {
            return
        }
        if let account = try? local.fetchAccount(id: id) {
            session = CurrentUser(id: account.id, name: account.name, email: account.email)
            return
        }
        let name = defaults.string(forKey: Keys.sessionName) ?? AppStrings.you
        let email = defaults.string(forKey: Keys.sessionEmail) ?? ""
        session = CurrentUser(id: id, name: name, email: email)
    }

    private func restoreRemoteSession() async {
        guard let remote, let user = await remote.currentSessionUser() else { return }
        setSession(user)
    }

    private func setSession(_ user: CurrentUser) {
        session = user
        defaults.set(user.id.uuidString, forKey: Keys.sessionID)
        defaults.set(user.name, forKey: Keys.sessionName)
        defaults.set(user.email, forKey: Keys.sessionEmail)
    }

    private func propagateNameToMemberships(_ user: CurrentUser) {
        guard let groups = try? local.fetchGroups(includeArchived: true) else { return }
        for group in groups {
            if var member = group.member(for: user.id) {
                member.name = user.name
                member.email = user.email
                try? local.updateMember(member)
            }
        }
    }
}
