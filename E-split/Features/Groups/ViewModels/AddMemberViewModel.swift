import Foundation

@Observable
final class AddMemberViewModel {
    var name = ""
    var email = ""
    var errorMessage: String?
    var isSaving = false

    private let repository: GroupRepositoryProtocol
    private let group: ExpenseGroup

    init(repository: GroupRepositoryProtocol, group: ExpenseGroup) {
        self.repository = repository
        self.group = group
    }

    func add() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AppError.memberNameRequired.localizedDescription
            return false
        }
        let normalizedEmail = EmailValidator.normalized(email)

        isSaving = true
        defer { isSaving = false }

        let member = GroupMember(
            userId: UUID(),
            groupId: group.id,
            name: trimmed,
            email: normalizedEmail,
            role: .member
        )

        do {
            try await repository.addMember(member)
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
}
