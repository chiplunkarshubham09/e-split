import Foundation

struct Settlement: Identifiable, Hashable, Codable {
    var id: UUID
    var groupId: UUID
    var fromUser: UUID
    var toUser: UUID
    var amount: Decimal
    var status: SettlementStatus
    var createdAt: Date
    var settledAt: Date?

    init(
        id: UUID = UUID(),
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        status: SettlementStatus = .pending,
        createdAt: Date = .now,
        settledAt: Date? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.fromUser = fromUser
        self.toUser = toUser
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
        self.settledAt = settledAt
    }
}
