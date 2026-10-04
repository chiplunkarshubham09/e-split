import XCTest
@testable import E_split

@MainActor
final class AuthAndInviteTests: XCTestCase {
    private var local: InMemoryLocalDataSource!
    private var groups: GroupRepository!
    private var auth: AuthRepository!

    override func setUp() {
        local = InMemoryLocalDataSource()
        groups = GroupRepository(local: local)
        auth = AuthRepository(local: local, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testRegisterAllowsAnyLengthPassword() async throws {
        try await auth.register(name: "Shub", email: "shub@example.com", password: "ab")
        XCTAssertTrue(auth.isLoggedIn)
        auth.logout()
        try await auth.login(email: "shub@example.com", password: "ab")
        XCTAssertTrue(auth.isLoggedIn)
    }

    func testRegisterAndLogin() async throws {
        try await auth.register(name: "Shub", email: "shub@example.com", password: "secret1")
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.currentUser.email, "shub@example.com")

        auth.logout()
        XCTAssertFalse(auth.isLoggedIn)

        try await auth.login(email: "shub@example.com", password: "secret1")
        XCTAssertTrue(auth.isLoggedIn)
    }

    func testLoginRejectsBadPassword() async {
        try? await auth.register(name: "Shub", email: "shub@example.com", password: "secret1")
        auth.logout()
        await XCTAssertThrowsErrorAsync {
            try await auth.login(email: "shub@example.com", password: "wrong")
        }
    }

    func testJoinGroupWithInviteCode() async throws {
        try await auth.register(name: "Shub", email: "shub@example.com", password: "secret1")
        let create = CreateGroupViewModel(repository: groups, currentUser: auth.currentUser)
        create.name = "Goa Trip"
        let group = await create.create()
        XCTAssertNotNil(group?.inviteCode)

        let guestDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let guestAuth = AuthRepository(local: local, defaults: guestDefaults)
        try await guestAuth.register(name: "Rahul", email: "rahul@example.com", password: "secret1")

        let joined = try await groups.joinGroup(inviteCode: group!.inviteCode, user: guestAuth.currentUser)
        XCTAssertEqual(joined.members.count, 2)
        XCTAssertNotNil(joined.member(for: guestAuth.currentUser.id))
    }

    func testInviteURLParsing() {
        let code = "AB12CD34"
        let url = InviteCode.url(for: code)
        XCTAssertEqual(InviteCode.parse(url), code)
        XCTAssertEqual(InviteCode.parse(URL(string: "esplit://join?code=ab12cd34")!), code)
    }

    func testMapperTurnsConfirmationEmailFailureIntoActionableError() {
        let error = NSError(
            domain: "Auth",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Error sending confirmation email"]
        )
        XCTAssertEqual(AuthRemoteErrorMapper.map(error), .confirmationEmailFailed)
        XCTAssertFalse(AppError.confirmationEmailFailed.localizedDescription.contains("Unable to save"))
    }

    func testMapperTurnsDisabledEmailProviderIntoActionableError() {
        let error = NSError(
            domain: "Auth",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Email signups are disabled"]
        )
        XCTAssertEqual(AuthRemoteErrorMapper.map(error), .emailAuthDisabled)
        XCTAssertEqual(AuthRemoteErrorMapper.map(text: "NO_PROFILE"), .memberNeedsAccount)
        XCTAssertNotEqual(AppError.emailAuthDisabled.localizedDescription, AppError.saveFailed.localizedDescription)
    }

    func testRegisterShowsDisabledEmailProviderInsteadOfUnableToSave() async {
        let remote = StubRemoteBackend()
        remote.registerError = NSError(
            domain: "Auth",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Email signups are disabled"]
        )
        let repository = AuthRepository(
            local: local,
            remote: remote,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let viewModel = AuthViewModel(auth: repository)
        viewModel.isRegistering = true
        viewModel.name = "Shub"
        viewModel.email = "shub@example.com"
        viewModel.password = "secret1"

        let succeeded = await viewModel.submit()

        XCTAssertFalse(succeeded)
        XCTAssertEqual(viewModel.errorMessage, AppError.emailAuthDisabled.localizedDescription)
        XCTAssertNotEqual(viewModel.errorMessage, AppError.saveFailed.localizedDescription)
    }

    func testMapperTurnsEmailNotConfirmedCodeIntoActionableError() {
        let error = NSError(
            domain: "Auth",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "email_not_confirmed"]
        )
        XCTAssertEqual(AuthRemoteErrorMapper.map(error), .emailNotConfirmed)
        XCTAssertNotEqual(AppError.emailNotConfirmed.localizedDescription, AppError.saveFailed.localizedDescription)
    }

    func testRegisterShowsEmailNotConfirmedInsteadOfUnableToSave() async {
        let remote = StubRemoteBackend()
        remote.registerError = NSError(
            domain: "Auth",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Email not confirmed"]
        )
        let repository = AuthRepository(
            local: local,
            remote: remote,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let viewModel = AuthViewModel(auth: repository)
        viewModel.isRegistering = true
        viewModel.name = "Shub"
        viewModel.email = "shub@example.com"
        viewModel.password = "secret1"

        let succeeded = await viewModel.submit()

        XCTAssertFalse(succeeded)
        XCTAssertEqual(viewModel.errorMessage, AppError.emailNotConfirmed.localizedDescription)
        XCTAssertNotEqual(viewModel.errorMessage, AppError.saveFailed.localizedDescription)
    }

    func testRegisterShowsConfirmationEmailFailureInsteadOfUnableToSave() async {
        let remote = StubRemoteBackend()
        remote.registerError = NSError(
            domain: "Auth",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Error sending confirmation email"]
        )
        let repository = AuthRepository(
            local: local,
            remote: remote,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let viewModel = AuthViewModel(auth: repository)
        viewModel.isRegistering = true
        viewModel.name = "Shub"
        viewModel.email = "shub@example.com"
        viewModel.password = "secret1"

        let succeeded = await viewModel.submit()

        XCTAssertFalse(succeeded)
        XCTAssertFalse(repository.isLoggedIn)
        XCTAssertEqual(viewModel.errorMessage, AppError.confirmationEmailFailed.localizedDescription)
        XCTAssertNotEqual(viewModel.errorMessage, AppError.saveFailed.localizedDescription)
    }

    func testRegisterSucceedsWhenRemoteReturnsUser() async throws {
        let remote = StubRemoteBackend()
        let repository = AuthRepository(
            local: local,
            remote: remote,
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        try await repository.register(name: "Shub", email: "shub@example.com", password: "secret1")
        XCTAssertTrue(repository.isLoggedIn)
        XCTAssertEqual(repository.currentUser.email, "shub@example.com")
    }

    func testSignupWithoutSessionLogsInInsteadOfAskingForInbox() async throws {
        let signedIn = CurrentUser(id: UUID(), name: "Shub", email: "shub@example.com")
        var loginCalled = false
        let user = try await RemoteAuthSession.currentUser(fromSignupSession: nil) {
            loginCalled = true
            return signedIn
        }
        XCTAssertTrue(loginCalled)
        XCTAssertEqual(user, signedIn)
    }

    func testSignupWithSessionDoesNotLogin() async throws {
        let sessionUser = CurrentUser(id: UUID(), name: "Shub", email: "shub@example.com")
        var loginCalled = false
        let user = try await RemoteAuthSession.currentUser(fromSignupSession: sessionUser) {
            loginCalled = true
            return CurrentUser(id: UUID(), name: "Other", email: "other@example.com")
        }
        XCTAssertFalse(loginCalled)
        XCTAssertEqual(user, sessionUser)
    }

    func testSignupWithoutSessionSurfacesEmailNotConfirmedWhenLoginFails() async {
        do {
            _ = try await RemoteAuthSession.currentUser(fromSignupSession: nil) {
                throw AppError.emailNotConfirmed
            }
            XCTFail("Expected emailNotConfirmed")
        } catch let error as AppError {
            XCTAssertEqual(error, .emailNotConfirmed)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        // expected
    }
}
