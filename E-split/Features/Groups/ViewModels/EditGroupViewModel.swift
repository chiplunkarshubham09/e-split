import Foundation

@Observable
final class EditGroupViewModel {
    var name: String
    var description: String
    var currency: String
    var type: GroupType?
    var errorMessage: String?
    var isSaving = false

    let currencies = ["INR", "USD", "EUR", "GBP", "AUD", "CAD"]
    var members: [GroupMember]

    private let repository: GroupRepositoryProtocol
    private var group: ExpenseGroup

    init(repository: GroupRepositoryProtocol, group: ExpenseGroup) {
        self.repository = repository
        self.group = group
        self.name = group.name
        self.description = group.description
        self.currency = group.currency
        self.type = group.type
        self.members = group.members
    }

    func save() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AppError.groupNameRequired.localizedDescription
            return false
        }
        isSaving = true
        defer { isSaving = false }
        group.name = trimmed
        group.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        group.currency = currency
        group.type = type
        do {
            try await repository.updateGroup(group)
            return true
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return false
        }
    }

    func removeMember(_ member: GroupMember) async -> String? {
        if group.members.count <= 1 {
            return AppError.cannotRemoveLastMember.localizedDescription
        }
        let remainingAdmins = group.members.filter { $0.role == .admin && $0.id != member.id }
        if member.role == .admin && remainingAdmins.isEmpty {
            return AppError.cannotRemoveLastAdmin.localizedDescription
        }
        do {
            try await repository.removeMember(id: member.id, groupId: group.id)
            group.members.removeAll { $0.id == member.id }
            members = group.members
            return nil
        } catch {
            return AppError.saveFailed.localizedDescription
        }
    }
}
