import Foundation

struct ParticipantDraft: Identifiable, Equatable {
    var id: UUID { member.userId }
    var member: GroupMember
    var isSelected: Bool
    var exactAmount: String
    var percentage: String
    var shares: String
}

@Observable
final class AddExpenseViewModel: Identifiable {
    let id = UUID()
    var title: String
    var amountText: String
    var notes: String
    var category: ExpenseCategory
    var paidBy: UUID
    var splitMethod: SplitMethod
    var participants: [ParticipantDraft]
    var createdAt: Date
    var errorMessage: String?
    var isSaving = false
    var isEditing: Bool { existing?.id != nil }

    let group: ExpenseGroup
    private let existing: Expense?
    let currentUserID: UUID
    private let expenseRepository: ExpenseRepositoryProtocol
    private let notificationService: NotificationScheduling

    init(
        group: ExpenseGroup,
        existing: Expense? = nil,
        expenseRepository: ExpenseRepositoryProtocol,
        currentUserID: UUID,
        notificationService: NotificationScheduling
    ) {
        self.group = group
        self.existing = existing
        self.expenseRepository = expenseRepository
        self.currentUserID = currentUserID
        self.notificationService = notificationService
        self.title = existing?.title ?? ""
        self.amountText = existing.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? ""
        self.notes = existing?.notes ?? ""
        self.category = existing?.category ?? .food
        self.paidBy = existing?.paidBy ?? currentUserID
        self.splitMethod = existing?.splitMethod ?? .equal
        self.createdAt = existing?.createdAt ?? .now
        let selectedIDs = Set(existing?.splits.map(\.userId) ?? group.members.map(\.userId))
        self.participants = group.members.map { member in
            let split = existing?.splits.first { $0.userId == member.userId }
            return ParticipantDraft(
                member: member,
                isSelected: selectedIDs.contains(member.userId),
                exactAmount: split.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "",
                percentage: split?.percentage.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                shares: split?.shares.map { NSDecimalNumber(decimal: $0).stringValue } ?? "1"
            )
        }
    }

    var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    var previewSplits: [CalculatedSplit] {
        (try? buildSplits()) ?? []
    }

    func save() async -> Bool {
        do {
            let expense = try makeExpense()
            isSaving = true
            defer { isSaving = false }
            try await expenseRepository.saveExpense(expense)
            let amountText = MoneyFormatter.compact(from: expense.amount, currencyCode: group.currency)
            if isEditing {
                await notificationService.notifyExpenseUpdated(title: expense.title, groupName: group.name)
            } else {
                await notificationService.notifyExpenseAdded(
                    title: expense.title,
                    amountText: amountText,
                    groupName: group.name
                )
            }
            errorMessage = nil
            return true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return false
        }
    }

    private func makeExpense() throws -> Expense {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw AppError.descriptionRequired }
        guard let amount = parsedAmount, amount.isStrictlyPositive else {
            throw AppError.amountMustBeGreaterThanZero
        }
        let calculated = try buildSplits()
        try ExpenseCalculationService.validateExpenseIntegrity(total: amount, splits: calculated)

        let expenseID = existing?.id ?? UUID()
        let splits = calculated.map {
            ExpenseSplit(
                expenseId: expenseID,
                userId: $0.userId,
                amount: $0.amount,
                percentage: $0.percentage,
                shares: $0.shares
            )
        }

        return Expense(
            id: expenseID,
            groupId: group.id,
            title: trimmedTitle,
            amount: amount.roundedToMoney,
            category: category,
            paidBy: paidBy,
            createdBy: existing?.createdBy ?? currentUserID,
            createdAt: createdAt,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            splitMethod: splitMethod,
            splits: splits
        )
    }

    private func buildSplits() throws -> [CalculatedSplit] {
        guard let amount = parsedAmount, amount.isStrictlyPositive else {
            throw AppError.amountMustBeGreaterThanZero
        }
        let selected = participants.filter(\.isSelected)
        guard !selected.isEmpty else { throw AppError.atLeastOneParticipantRequired }

        let inputs: [SplitParticipantInput] = selected.map { draft in
            SplitParticipantInput(
                userId: draft.member.userId,
                amount: Decimal(string: draft.exactAmount.replacingOccurrences(of: ",", with: ".")) ?? 0,
                percentage: Decimal(string: draft.percentage.replacingOccurrences(of: ",", with: ".")) ?? 0,
                shares: Decimal(string: draft.shares.replacingOccurrences(of: ",", with: ".")) ?? 0
            )
        }
        return try ExpenseCalculationService.calculateSplits(
            total: amount,
            method: splitMethod,
            participants: inputs
        )
    }
}
