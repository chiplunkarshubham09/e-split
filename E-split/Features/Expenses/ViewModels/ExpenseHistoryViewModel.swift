import Foundation

@Observable
final class ExpenseHistoryViewModel {
    var expenses: [Expense]
    var searchText = ""
    var selectedCategory: ExpenseCategory?
    var selectedMemberID: UUID?
    var minAmountText = ""
    var maxAmountText = ""
    var startDate: Date?
    var endDate: Date?

    let group: ExpenseGroup
    let currentUserID: UUID

    init(group: ExpenseGroup, expenses: [Expense], currentUserID: UUID) {
        self.group = group
        self.expenses = expenses
        self.currentUserID = currentUserID
    }

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let query = searchText.lowercased()
                let payer = group.displayName(for: expense.paidBy, currentUserID: currentUserID).lowercased()
                if !expense.title.lowercased().contains(query)
                    && !expense.notes.lowercased().contains(query)
                    && !payer.contains(query) {
                    return false
                }
            }
            if let selectedCategory, expense.category != selectedCategory {
                return false
            }
            if let selectedMemberID, expense.paidBy != selectedMemberID &&
                !expense.splits.contains(where: { $0.userId == selectedMemberID }) {
                return false
            }
            if let min = Decimal(string: minAmountText), expense.amount < min {
                return false
            }
            if let max = Decimal(string: maxAmountText), expense.amount > max {
                return false
            }
            if let startDate, expense.createdAt < Calendar.current.startOfDay(for: startDate) {
                return false
            }
            if let endDate {
                let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
                if expense.createdAt >= end {
                    return false
                }
            }
            return true
        }
    }

    func apply(_ expenses: [Expense]) {
        self.expenses = expenses
    }
}
