import Foundation
import SwiftData

@Model
final class ExpenseSplitEntity {
    @Attribute(.unique) var id: UUID
    var expenseId: UUID
    var userId: UUID
    var amount: Decimal
    var percentage: Decimal?
    var shares: Decimal?
    var expense: ExpenseEntity?

    init(
        id: UUID,
        expenseId: UUID,
        userId: UUID,
        amount: Decimal,
        percentage: Decimal?,
        shares: Decimal?
    ) {
        self.id = id
        self.expenseId = expenseId
        self.userId = userId
        self.amount = amount
        self.percentage = percentage
        self.shares = shares
    }
}
