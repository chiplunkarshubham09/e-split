import Foundation

@Observable
final class GroupDashboardViewModel {
    var group: ExpenseGroup
    var expenses: [Expense] = []
    var settlements: [Settlement] = []
    var balances: [MemberBalance] = []
    var debts: [Debt] = []
    var errorMessage: String?
    var showAddMember = false
    var showEditGroup = false
    var showInvite = false
    var confirmDelete = false

    private let groupRepository: GroupRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol
    private let settlementRepository: SettlementRepositoryProtocol
    let currentUserID: UUID

    init(
        group: ExpenseGroup,
        groupRepository: GroupRepositoryProtocol,
        expenseRepository: ExpenseRepositoryProtocol,
        settlementRepository: SettlementRepositoryProtocol,
        currentUserID: UUID
    ) {
        self.group = group
        self.groupRepository = groupRepository
        self.expenseRepository = expenseRepository
        self.settlementRepository = settlementRepository
        self.currentUserID = currentUserID
    }

    var isAdmin: Bool {
        group.member(for: currentUserID)?.role == .admin
    }

    var totalExpenses: Decimal {
        expenses.reduce(.moneyZero) { $0 + $1.amount }
    }

    var youOwe: Decimal {
        BalanceService.summary(for: currentUserID, balances: balances).owes
    }

    var youAreOwed: Decimal {
        BalanceService.summary(for: currentUserID, balances: balances).isOwed
    }

    var recentExpenses: [Expense] {
        Array(expenses.prefix(5))
    }

    func load() async {
        do {
            if let latest = try await groupRepository.fetchGroup(id: group.id) {
                group = latest
            }
            expenses = try await expenseRepository.fetchExpenses(groupId: group.id)
            settlements = try await settlementRepository.fetchSettlements(groupId: group.id)
            balances = try BalanceService.netBalances(
                members: group.members,
                expenses: expenses,
                settlements: settlements
            )
            debts = BalanceService.simplifiedDebts(from: balances)
            errorMessage = nil
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = AppError.loadFailed.localizedDescription
        }
    }

    func archiveGroup() async {
        group.isArchived = true
        do {
            try await groupRepository.updateGroup(group)
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
        }
    }

    func deleteGroup() async {
        do {
            try await groupRepository.deleteGroup(id: group.id)
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
        }
    }
}
