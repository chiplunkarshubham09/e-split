import Foundation

@Observable
final class InviteMembersViewModel {
    var group: ExpenseGroup
    var errorMessage: String?

    private let repository: GroupRepositoryProtocol

    init(group: ExpenseGroup, repository: GroupRepositoryProtocol) {
        self.group = group
        self.repository = repository
    }

    var inviteURL: URL {
        InviteCode.url(for: group.inviteCode)
    }

    var inviteMessage: String {
        "Join \(group.name) on Split Expense: \(inviteURL.absoluteString)"
    }

    func ensureCode() async {
        if group.inviteCode.isEmpty {
            group.inviteCode = InviteCode.generate()
            try? await repository.updateGroup(group)
        }
    }

    func refreshCode() async {
        group.inviteCode = InviteCode.generate()
        do {
            try await repository.updateGroup(group)
            errorMessage = nil
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
        }
    }
}
