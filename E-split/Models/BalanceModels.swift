import Foundation

struct SplitParticipantInput: Equatable, Hashable, Identifiable {
    var id: UUID { userId }
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal
    var shares: Decimal
}

struct CalculatedSplit: Equatable, Hashable {
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal?
    var shares: Decimal?
}

struct MemberBalance: Identifiable, Equatable, Hashable {
    var id: UUID { userId }
    var userId: UUID
    var name: String
    var net: Decimal

    var amountOwedToOthers: Decimal {
        net < 0 ? -net : 0
    }

    var amountOwedByOthers: Decimal {
        net > 0 ? net : 0
    }
}

struct Debt: Identifiable, Equatable, Hashable {
    var id: String { "\(fromUserId.uuidString)-\(toUserId.uuidString)-\(amount)" }
    var fromUserId: UUID
    var toUserId: UUID
    var amount: Decimal
}
