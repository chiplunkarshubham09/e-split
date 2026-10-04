import Foundation

enum BalanceService {
    static func netBalances(
        members: [GroupMember],
        expenses: [Expense],
        settlements: [Settlement]
    ) throws -> [MemberBalance] {
        var nets: [UUID: Decimal] = [:]
        for member in members {
            nets[member.userId] = .moneyZero
        }

        for expense in expenses {
            nets[expense.paidBy, default: .moneyZero] += expense.amount
            for split in expense.splits {
                nets[split.userId, default: .moneyZero] -= split.amount
            }
        }

        for settlement in settlements where settlement.status == .paid {
            nets[settlement.fromUser, default: .moneyZero] += settlement.amount
            nets[settlement.toUser, default: .moneyZero] -= settlement.amount
        }

        try validateZeroSum(nets)

        return members.map { member in
            MemberBalance(
                userId: member.userId,
                name: member.name,
                net: (nets[member.userId] ?? .moneyZero).roundedToMoney
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func simplifiedDebts(from balances: [MemberBalance]) -> [Debt] {
        var debtors = balances
            .filter { $0.net < 0 }
            .map { (userId: $0.userId, amount: -$0.net.roundedToMoney) }
            .sorted { $0.amount > $1.amount }

        var creditors = balances
            .filter { $0.net > 0 }
            .map { (userId: $0.userId, amount: $0.net.roundedToMoney) }
            .sorted { $0.amount > $1.amount }

        var debts: [Debt] = []
        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let payment = min(debtors[debtorIndex].amount, creditors[creditorIndex].amount).roundedToMoney
            if payment > 0 {
                debts.append(
                    Debt(
                        fromUserId: debtors[debtorIndex].userId,
                        toUserId: creditors[creditorIndex].userId,
                        amount: payment
                    )
                )
            }

            debtors[debtorIndex].amount = (debtors[debtorIndex].amount - payment).roundedToMoney
            creditors[creditorIndex].amount = (creditors[creditorIndex].amount - payment).roundedToMoney

            if debtors[debtorIndex].amount.isMoneyZero {
                debtorIndex += 1
            }
            if creditors[creditorIndex].amount.isMoneyZero {
                creditorIndex += 1
            }
        }

        return debts
    }

    static func summary(
        for userId: UUID,
        balances: [MemberBalance]
    ) -> (owes: Decimal, isOwed: Decimal) {
        guard let mine = balances.first(where: { $0.userId == userId }) else {
            return (.moneyZero, .moneyZero)
        }
        return (mine.amountOwedToOthers, mine.amountOwedByOthers)
    }

    static func validateZeroSum(_ nets: [UUID: Decimal]) throws {
        let total = nets.values.reduce(Decimal.moneyZero, +).roundedToMoney
        if !total.isMoneyZero {
            throw AppError.balancesMustSumToZero
        }
    }
}
