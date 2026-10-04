import Foundation

protocol RemoteBackend {
    func currentSessionUser() async -> CurrentUser?
    func register(name: String, email: String, password: String) async throws -> CurrentUser
    func login(email: String, password: String) async throws -> CurrentUser
    func logout() async
    func updateProfileName(_ name: String, userId: UUID) async throws

    func fetchGroups() async throws -> [ExpenseGroup]
    func fetchGroup(id: UUID) async throws -> ExpenseGroup?
    func fetchGroup(inviteCode: String) async throws -> ExpenseGroup?
    func createGroup(_ group: ExpenseGroup) async throws
    func updateGroup(_ group: ExpenseGroup) async throws
    func deleteGroup(id: UUID) async throws
    func addMember(_ member: GroupMember) async throws
    func updateMember(_ member: GroupMember) async throws
    func removeMember(id: UUID, groupId: UUID) async throws
    func joinGroup(inviteCode: String, user: CurrentUser) async throws -> ExpenseGroup

    func fetchExpenses(groupId: UUID) async throws -> [Expense]
    func saveExpense(_ expense: Expense) async throws
    func deleteExpense(id: UUID) async throws

    func fetchSettlements(groupId: UUID) async throws -> [Settlement]
    func saveSettlement(_ settlement: Settlement) async throws
}
