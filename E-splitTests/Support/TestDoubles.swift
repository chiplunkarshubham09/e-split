import Foundation
@testable import E_split

@MainActor
final class InMemoryLocalDataSource: LocalExpenseDataSource {
    private var groups: [UUID: ExpenseGroup] = [:]
    private var expenses: [UUID: Expense] = [:]
    private var settlements: [UUID: Settlement] = [:]
    private var accounts: [UUID: StoredAccount] = [:]

    func fetchGroups(includeArchived: Bool) throws -> [ExpenseGroup] {
        groups.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchGroup(id: UUID) throws -> ExpenseGroup? {
        groups[id]
    }

    func fetchGroup(inviteCode: String) throws -> ExpenseGroup? {
        let code = InviteCode.normalized(inviteCode)
        return groups.values.first { InviteCode.normalized($0.inviteCode) == code }
    }

    func saveGroup(_ group: ExpenseGroup) throws {
        groups[group.id] = group
    }

    func cacheGroup(_ group: ExpenseGroup) throws {
        groups[group.id] = group
    }

    func deleteGroup(id: UUID) throws {
        groups[id] = nil
        expenses = expenses.filter { $0.value.groupId != id }
        settlements = settlements.filter { $0.value.groupId != id }
    }

    func addMember(_ member: GroupMember) throws {
        guard var group = groups[member.groupId] else { throw AppError.groupNotFound }
        if group.members.contains(where: { $0.userId == member.userId }) {
            return
        }
        group.members.append(member)
        groups[member.groupId] = group
    }

    func updateMember(_ member: GroupMember) throws {
        guard var group = groups[member.groupId] else { throw AppError.groupNotFound }
        guard let index = group.members.firstIndex(where: { $0.id == member.id }) else {
            throw AppError.memberNotFound
        }
        group.members[index] = member
        groups[member.groupId] = group
    }

    func deleteMember(id: UUID, groupId: UUID) throws {
        guard var group = groups[groupId] else { throw AppError.groupNotFound }
        group.members.removeAll { $0.id == id }
        groups[groupId] = group
    }

    func fetchExpenses(groupId: UUID) throws -> [Expense] {
        expenses.values
            .filter { $0.groupId == groupId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchExpense(id: UUID) throws -> Expense? {
        expenses[id]
    }

    func saveExpense(_ expense: Expense) throws {
        guard groups[expense.groupId] != nil else { throw AppError.groupNotFound }
        expenses[expense.id] = expense
    }

    func deleteExpense(id: UUID) throws {
        expenses[id] = nil
    }

    func fetchSettlements(groupId: UUID) throws -> [Settlement] {
        settlements.values
            .filter { $0.groupId == groupId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveSettlement(_ settlement: Settlement) throws {
        guard groups[settlement.groupId] != nil else { throw AppError.groupNotFound }
        settlements[settlement.id] = settlement
    }

    func deleteSettlement(id: UUID) throws {
        settlements[id] = nil
    }

    func fetchAccount(email: String) throws -> StoredAccount? {
        let normalized = EmailValidator.normalized(email)
        return accounts.values.first { $0.email == normalized }
    }

    func fetchAccount(id: UUID) throws -> StoredAccount? {
        accounts[id]
    }

    func saveAccount(_ account: StoredAccount) throws {
        accounts[account.id] = account
    }
}

@MainActor
final class MockCurrentUserStore: CurrentUserProviding {
    var currentUser: CurrentUser

    init(user: CurrentUser = CurrentUser(id: UUID(), name: "Shub", email: "shub@example.com")) {
        self.currentUser = user
    }

    func updateName(_ name: String) {
        currentUser.name = name
    }
}

@MainActor
final class MockNotificationService: NotificationScheduling {
    var addedCount = 0
    var updatedCount = 0
    var reminderCount = 0

    func requestAuthorization() async {}

    func notifyExpenseAdded(title: String, amountText: String, groupName: String) async {
        addedCount += 1
    }

    func notifyExpenseUpdated(title: String, groupName: String) async {
        updatedCount += 1
    }

    func notifySettlementReminder(fromName: String, toName: String, amountText: String) async {
        reminderCount += 1
    }
}

@MainActor
final class StubRemoteBackend: RemoteBackend {
    var registerError: Error?
    var loginError: Error?
    var addMemberError: Error?
    var registeredUser = CurrentUser(id: UUID(), name: "Shub", email: "shub@example.com")

    func currentSessionUser() async -> CurrentUser? { nil }

    func register(name: String, email: String, password: String) async throws -> CurrentUser {
        if let registerError { throw registerError }
        return CurrentUser(id: registeredUser.id, name: name, email: email)
    }

    func login(email: String, password: String) async throws -> CurrentUser {
        if let loginError { throw loginError }
        return registeredUser
    }

    func logout() async {}
    func updateProfileName(_ name: String, userId: UUID) async throws {}
    func fetchGroups() async throws -> [ExpenseGroup] { [] }
    func fetchGroup(id: UUID) async throws -> ExpenseGroup? { nil }
    func fetchGroup(inviteCode: String) async throws -> ExpenseGroup? { nil }
    func createGroup(_ group: ExpenseGroup) async throws {}
    func updateGroup(_ group: ExpenseGroup) async throws {}
    func deleteGroup(id: UUID) async throws {}
    func addMember(_ member: GroupMember) async throws {
        if let addMemberError { throw addMemberError }
    }
    func updateMember(_ member: GroupMember) async throws {}
    func removeMember(id: UUID, groupId: UUID) async throws {}
    func joinGroup(inviteCode: String, user: CurrentUser) async throws -> ExpenseGroup {
        throw AppError.invalidInvite
    }
    func fetchExpenses(groupId: UUID) async throws -> [Expense] { [] }
    func saveExpense(_ expense: Expense) async throws {}
    func deleteExpense(id: UUID) async throws {}
    func fetchSettlements(groupId: UUID) async throws -> [Settlement] { [] }
    func saveSettlement(_ settlement: Settlement) async throws {}
}

@MainActor
enum TestMembers {
    static let shubID = UUID()
    static let rahulID = UUID()
    static let amitID = UUID()
    static let priyaID = UUID()

    static func group() -> ExpenseGroup {
        let groupID = UUID()
        let members = [
            GroupMember(userId: shubID, groupId: groupID, name: "Shub", role: .admin),
            GroupMember(userId: rahulID, groupId: groupID, name: "Rahul", role: .member),
            GroupMember(userId: amitID, groupId: groupID, name: "Amit", role: .member),
            GroupMember(userId: priyaID, groupId: groupID, name: "Priya", role: .member)
        ]
        return ExpenseGroup(id: groupID, name: "Goa Trip", createdBy: shubID, members: members)
    }
}
