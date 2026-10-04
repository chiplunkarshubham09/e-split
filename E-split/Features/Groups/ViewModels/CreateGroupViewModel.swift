import Foundation

@Observable
final class CreateGroupViewModel {
    var name = ""
    var description = ""
    var currency = AppStrings.defaultCurrencyCode
    var type: GroupType?
    var errorMessage: String?
    var isSaving = false

    let currencies = ["INR", "USD", "EUR", "GBP", "AUD", "CAD"]

    private let repository: GroupRepositoryProtocol
    private let currentUser: CurrentUser

    init(repository: GroupRepositoryProtocol, currentUser: CurrentUser) {
        self.repository = repository
        self.currentUser = currentUser
    }

    func create() async -> ExpenseGroup? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = AppError.groupNameRequired.localizedDescription
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        let groupID = UUID()
        let creator = GroupMember(
            userId: currentUser.id,
            groupId: groupID,
            name: currentUser.name,
            email: currentUser.email,
            role: .admin
        )
        let group = ExpenseGroup(
            id: groupID,
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            currency: currency,
            type: type,
            createdBy: currentUser.id,
            members: [creator]
        )

        do {
            try await repository.createGroup(group)
            errorMessage = nil
            return group
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return nil
        }
    }
}
