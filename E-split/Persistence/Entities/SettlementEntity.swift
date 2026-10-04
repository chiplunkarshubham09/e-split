import Foundation
import SwiftData

@Model
final class SettlementEntity {
    @Attribute(.unique) var id: UUID
    var groupId: UUID
    var fromUser: UUID
    var toUser: UUID
    var amount: Decimal
    var statusRaw: String
    var createdAt: Date
    var settledAt: Date?
    var group: GroupEntity?

    init(
        id: UUID,
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        statusRaw: String,
        createdAt: Date,
        settledAt: Date?
    ) {
        self.id = id
        self.groupId = groupId
        self.fromUser = fromUser
        self.toUser = toUser
        self.amount = amount
        self.statusRaw = statusRaw
        self.createdAt = createdAt
        self.settledAt = settledAt
    }
}
