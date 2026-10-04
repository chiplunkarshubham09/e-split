import Foundation
import SwiftData

@Model
final class ExpenseEntity {
    @Attribute(.unique) var id: UUID
    var groupId: UUID
    var title: String
    var amount: Decimal
    var categoryRaw: String
    var paidBy: UUID
    var createdBy: UUID
    var createdAt: Date
    var notes: String
    var splitMethodRaw: String
    var group: GroupEntity?

    @Relationship(deleteRule: .cascade, inverse: \ExpenseSplitEntity.expense)
    var splits: [ExpenseSplitEntity] = []

    init(
        id: UUID,
        groupId: UUID,
        title: String,
        amount: Decimal,
        categoryRaw: String,
        paidBy: UUID,
        createdBy: UUID,
        createdAt: Date,
        notes: String,
        splitMethodRaw: String
    ) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.amount = amount
        self.categoryRaw = categoryRaw
        self.paidBy = paidBy
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.notes = notes
        self.splitMethodRaw = splitMethodRaw
    }
}
