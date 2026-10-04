import Foundation

struct ExpenseSplit: Identifiable, Hashable, Codable {
    var id: UUID
    var expenseId: UUID
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal?
    var shares: Decimal?

    init(
        id: UUID = UUID(),
        expenseId: UUID,
        userId: UUID,
        amount: Decimal,
        percentage: Decimal? = nil,
        shares: Decimal? = nil
    ) {
        self.id = id
        self.expenseId = expenseId
        self.userId = userId
        self.amount = amount
        self.percentage = percentage
        self.shares = shares
    }
}
