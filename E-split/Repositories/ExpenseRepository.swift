import Foundation

protocol ExpenseRepositoryProtocol {
    func fetchExpenses(groupId: UUID) async throws -> [Expense]
    func fetchExpense(id: UUID) async throws -> Expense?
    func saveExpense(_ expense: Expense) async throws
    func deleteExpense(id: UUID) async throws
}

final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let local: LocalExpenseDataSource
    private let remote: RemoteBackend?

    init(local: LocalExpenseDataSource, remote: RemoteBackend? = nil) {
        self.local = local
        self.remote = remote
    }

    func fetchExpenses(groupId: UUID) async throws -> [Expense] {
        if let remote {
            do {
                let expenses = try await remote.fetchExpenses(groupId: groupId)
                for expense in expenses {
                    try? local.saveExpense(expense)
                }
                return expenses
            } catch {
                return try local.fetchExpenses(groupId: groupId)
            }
        }
        return try local.fetchExpenses(groupId: groupId)
    }

    func fetchExpense(id: UUID) async throws -> Expense? {
        try local.fetchExpense(id: id)
    }

    func saveExpense(_ expense: Expense) async throws {
        if let remote {
            try await remote.saveExpense(expense)
        }
        try local.saveExpense(expense)
    }

    func deleteExpense(id: UUID) async throws {
        if let remote {
            try await remote.deleteExpense(id: id)
        }
        try local.deleteExpense(id: id)
    }
}
