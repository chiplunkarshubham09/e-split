import Foundation

enum ExpenseCalculationService {
    static func calculateSplits(
        total: Decimal,
        method: SplitMethod,
        participants: [SplitParticipantInput]
    ) throws -> [CalculatedSplit] {
        guard total.isStrictlyPositive else {
            throw AppError.amountMustBeGreaterThanZero
        }
        guard !participants.isEmpty else {
            throw AppError.atLeastOneParticipantRequired
        }

        switch method {
        case .equal:
            return try equalSplits(total: total, participants: participants)
        case .exactAmount:
            return try exactSplits(total: total, participants: participants)
        case .percentage:
            return try percentageSplits(total: total, participants: participants)
        case .shares:
            return try shareSplits(total: total, participants: participants)
        }
    }

    static func validateExpenseIntegrity(total: Decimal, splits: [CalculatedSplit]) throws {
        let sum = splits.reduce(Decimal.moneyZero) { $0 + $1.amount }.roundedToMoney
        if sum != total.roundedToMoney {
            throw AppError.splitAmountsMustEqualTotal(expected: total.roundedToMoney)
        }
    }

    private static func equalSplits(
        total: Decimal,
        participants: [SplitParticipantInput]
    ) throws -> [CalculatedSplit] {
        let units = MoneyRounding.toMinorUnits(total)
        let count = participants.count
        let base = units / count
        let remainder = units % count

        return participants.enumerated().map { index, participant in
            let extra = index < remainder ? 1 : 0
            let amount = MoneyRounding.fromMinorUnits(base + extra)
            let percentage = (amount / total * 100).roundedToMoney
            return CalculatedSplit(
                userId: participant.userId,
                amount: amount,
                percentage: percentage,
                shares: 1
            )
        }
    }

    private static func exactSplits(
        total: Decimal,
        participants: [SplitParticipantInput]
    ) throws -> [CalculatedSplit] {
        let splits = participants.map { participant in
            CalculatedSplit(
                userId: participant.userId,
                amount: participant.amount.roundedToMoney,
                percentage: total == 0 ? nil : (participant.amount / total * 100).roundedToMoney,
                shares: nil
            )
        }
        try validateExpenseIntegrity(total: total, splits: splits)
        return splits
    }

    private static func percentageSplits(
        total: Decimal,
        participants: [SplitParticipantInput]
    ) throws -> [CalculatedSplit] {
        let percentSum = participants.reduce(Decimal.moneyZero) { $0 + $1.percentage }.roundedToMoney
        if percentSum != 100 {
            throw AppError.percentagesMustTotalOneHundred
        }

        let units = MoneyRounding.toMinorUnits(total)
        var remaining = units
        var splits: [CalculatedSplit] = []

        for (index, participant) in participants.enumerated() {
            let isLast = index == participants.count - 1
            let shareUnits = allocatedMinorUnits(
                totalUnits: units,
                ratio: participant.percentage / 100,
                remaining: remaining,
                isLast: isLast
            )
            remaining -= shareUnits
            splits.append(
                CalculatedSplit(
                    userId: participant.userId,
                    amount: MoneyRounding.fromMinorUnits(shareUnits),
                    percentage: participant.percentage.roundedToMoney,
                    shares: nil
                )
            )
        }

        try validateExpenseIntegrity(total: total, splits: splits)
        return splits
    }

    private static func shareSplits(
        total: Decimal,
        participants: [SplitParticipantInput]
    ) throws -> [CalculatedSplit] {
        let totalShares = participants.reduce(Decimal.moneyZero) { $0 + $1.shares }
        guard totalShares.isStrictlyPositive else {
            throw AppError.sharesMustBeValid
        }
        guard participants.allSatisfy({ $0.shares.isStrictlyPositive }) else {
            throw AppError.sharesMustBeValid
        }

        let units = MoneyRounding.toMinorUnits(total)
        var remaining = units
        var splits: [CalculatedSplit] = []

        for (index, participant) in participants.enumerated() {
            let isLast = index == participants.count - 1
            let ratio = participant.shares / totalShares
            let shareUnits = allocatedMinorUnits(
                totalUnits: units,
                ratio: ratio,
                remaining: remaining,
                isLast: isLast
            )
            remaining -= shareUnits
            splits.append(
                CalculatedSplit(
                    userId: participant.userId,
                    amount: MoneyRounding.fromMinorUnits(shareUnits),
                    percentage: (ratio * 100).roundedToMoney,
                    shares: participant.shares.roundedToMoney
                )
            )
        }

        try validateExpenseIntegrity(total: total, splits: splits)
        return splits
    }

    private static func allocatedMinorUnits(
        totalUnits: Int,
        ratio: Decimal,
        remaining: Int,
        isLast: Bool
    ) -> Int {
        if isLast {
            return remaining
        }
        var product = Decimal(totalUnits) * ratio
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
