import Foundation

struct Expense: Identifiable, Hashable, Codable {
    var id: UUID
    var groupId: UUID
    var title: String
    var amount: Decimal
    var category: ExpenseCategory
    var paidBy: UUID
    var createdBy: UUID
    var createdAt: Date
    var notes: String
    var splitMethod: SplitMethod
    var splits: [ExpenseSplit]

    init(
        id: UUID = UUID(),
        groupId: UUID,
        title: String,
        amount: Decimal,
        category: ExpenseCategory,
        paidBy: UUID,
        createdBy: UUID,
        createdAt: Date = .now,
        notes: String = "",
        splitMethod: SplitMethod,
        splits: [ExpenseSplit] = []
    ) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.amount = amount
        self.category = category
        self.paidBy = paidBy
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.notes = notes
        self.splitMethod = splitMethod
        self.splits = splits
    }
}
