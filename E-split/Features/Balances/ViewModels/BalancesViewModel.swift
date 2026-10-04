import Foundation

@Observable
final class BalancesViewModel {
    var balances: [MemberBalance] = []
    var debts: [Debt] = []
    var errorMessage: String?

    let group: ExpenseGroup
    let currentUserID: UUID

    init(group: ExpenseGroup, currentUserID: UUID) {
        self.group = group
        self.currentUserID = currentUserID
    }

    var youOwe: Decimal {
        BalanceService.summary(for: currentUserID, balances: balances).owes
    }

    var youAreOwed: Decimal {
        BalanceService.summary(for: currentUserID, balances: balances).isOwed
    }

    func apply(expenses: [Expense], settlements: [Settlement], members: [GroupMember]) {
        do {
            balances = try BalanceService.netBalances(
                members: members,
                expenses: expenses,
                settlements: settlements
            )
            debts = BalanceService.simplifiedDebts(from: balances)
            errorMessage = nil
        } catch {
            errorMessage = AppError.balancesMustSumToZero.localizedDescription
        }
    }

    func sentence(for debt: Debt) -> String {
        let amount = MoneyFormatter.compact(from: debt.amount, currencyCode: group.currency)
        let from = group.displayName(for: debt.fromUserId, currentUserID: currentUserID)
        let to = group.displayName(for: debt.toUserId, currentUserID: currentUserID)

        if debt.toUserId == currentUserID {
            return "\(from) owes you \(amount)"
        }
        if debt.fromUserId == currentUserID {
            return "You owe \(to) \(amount)"
        }
        return "\(from) owes \(to) \(amount)"
    }
}
