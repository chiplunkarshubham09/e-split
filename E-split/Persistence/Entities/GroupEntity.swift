import Foundation
import SwiftData

@Model
final class GroupEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var groupDescription: String
    var currency: String
    var typeRaw: String?
    var createdBy: UUID
    var createdAt: Date
    var isArchived: Bool
    var inviteCode: String

    @Relationship(deleteRule: .cascade, inverse: \GroupMemberEntity.group)
    var members: [GroupMemberEntity] = []

    @Relationship(deleteRule: .cascade, inverse: \ExpenseEntity.group)
    var expenses: [ExpenseEntity] = []

    @Relationship(deleteRule: .cascade, inverse: \SettlementEntity.group)
    var settlements: [SettlementEntity] = []

    init(
        id: UUID,
        name: String,
        groupDescription: String,
        currency: String,
        typeRaw: String?,
        createdBy: UUID,
        createdAt: Date,
        isArchived: Bool,
        inviteCode: String
    ) {
        self.id = id
        self.name = name
        self.groupDescription = groupDescription
        self.currency = currency
        self.typeRaw = typeRaw
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.inviteCode = inviteCode
    }
}
