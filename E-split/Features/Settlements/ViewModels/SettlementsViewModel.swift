import Foundation

@Observable
final class SettlementsViewModel {
    var settlements: [Settlement] = []
    var availableDebts: [Debt] = []
    var errorMessage: String?
    var isSaving = false

    let group: ExpenseGroup
    let currentUserID: UUID
    private let expenseRepository: ExpenseRepositoryProtocol
    private let repository: SettlementRepositoryProtocol
    private let notificationService: NotificationScheduling
    private var latestExpenses: [Expense] = []
    private var latestMembers: [GroupMember] = []

    init(
        group: ExpenseGroup,
        currentUserID: UUID,
        expenseRepository: ExpenseRepositoryProtocol,
        repository: SettlementRepositoryProtocol,
        notificationService: NotificationScheduling
    ) {
        self.group = group
        self.currentUserID = currentUserID
        self.expenseRepository = expenseRepository
        self.repository = repository
        self.notificationService = notificationService
        self.latestMembers = group.members
    }

    var pending: [Settlement] {
        settlements.filter { $0.status == .pending }
    }

    var paid: [Settlement] {
        settlements.filter { $0.status == .paid }
    }

    func load(expenses: [Expense], settlements: [Settlement], members: [GroupMember]) {
        latestExpenses = expenses
        latestMembers = members
        self.settlements = settlements
        refreshDebts()
    }

    func reload() async {
        do {
            latestMembers = group.members
            latestExpenses = try await expenseRepository.fetchExpenses(groupId: group.id)
            settlements = try await repository.fetchSettlements(groupId: group.id)
            refreshDebts()
            errorMessage = nil
        } catch {
            errorMessage = AppError.loadFailed.localizedDescription
        }
    }

    func record(_ debt: Debt) async {
        isSaving = true
        defer { isSaving = false }
        let settlement = Settlement(
            groupId: group.id,
            fromUser: debt.fromUserId,
            toUser: debt.toUserId,
            amount: debt.amount,
            status: .pending
        )
        do {
            try await repository.saveSettlement(settlement)
            await reload()
            let from = group.displayName(for: debt.fromUserId, currentUserID: currentUserID)
            let to = group.displayName(for: debt.toUserId, currentUserID: currentUserID)
            await notificationService.notifySettlementReminder(
                fromName: from,
                toName: to,
                amountText: MoneyFormatter.compact(from: debt.amount, currencyCode: group.currency)
            )
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
        }
    }

    func markPaid(_ settlement: Settlement) async {
        isSaving = true
        defer { isSaving = false }
        var updated = settlement
        updated.status = .paid
        updated.settledAt = .now
        do {
            try await repository.saveSettlement(updated)
            await reload()
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
        }
    }

    func description(for settlement: Settlement) -> String {
        let from = group.displayName(for: settlement.fromUser, currentUserID: currentUserID)
        let to = group.displayName(for: settlement.toUser, currentUserID: currentUserID)
        let amount = MoneyFormatter.compact(from: settlement.amount, currencyCode: group.currency)
        if settlement.status == .paid {
            return "\(from) paid \(to) \(amount)"
        }
        return "\(from) owes \(to) \(amount)"
    }

    private func refreshDebts() {
        if let balances = try? BalanceService.netBalances(
            members: latestMembers,
            expenses: latestExpenses,
            settlements: settlements
        ) {
            availableDebts = BalanceService.simplifiedDebts(from: balances)
        }
    }
}
