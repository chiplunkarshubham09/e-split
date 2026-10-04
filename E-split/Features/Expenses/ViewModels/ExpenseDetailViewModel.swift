import Foundation

@Observable
final class ExpenseDetailViewModel {
    var expense: Expense
    var confirmDelete = false
    var showEdit = false
    var errorMessage: String?

    let group: ExpenseGroup
    let currentUserID: UUID
    private let expenseRepository: ExpenseRepositoryProtocol

    init(
        expense: Expense,
        group: ExpenseGroup,
        currentUserID: UUID,
        expenseRepository: ExpenseRepositoryProtocol
    ) {
        self.expense = expense
        self.group = group
        self.currentUserID = currentUserID
        self.expenseRepository = expenseRepository
    }

    func reload() async {
        if let latest = try? await expenseRepository.fetchExpense(id: expense.id) {
            expense = latest
        }
    }

    func delete() async -> Bool {
        do {
            try await expenseRepository.deleteExpense(id: expense.id)
            return true
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return false
        }
    }
}
