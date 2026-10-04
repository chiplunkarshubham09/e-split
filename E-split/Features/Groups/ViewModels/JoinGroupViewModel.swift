import Foundation

@Observable
final class JoinGroupViewModel {
    var errorMessage: String?
    var isJoining = false
    var groupPreview: ExpenseGroup?

    let inviteCode: String
    private let groupRepository: GroupRepositoryProtocol
    private let currentUser: CurrentUser

    init(
        inviteCode: String,
        groupRepository: GroupRepositoryProtocol,
        currentUser: CurrentUser
    ) {
        self.inviteCode = InviteCode.normalized(inviteCode)
        self.groupRepository = groupRepository
        self.currentUser = currentUser
    }

    func loadPreview() async {
        groupPreview = try? await groupRepository.fetchGroup(inviteCode: inviteCode)
        if groupPreview == nil {
            errorMessage = AppError.invalidInvite.localizedDescription
        }
    }

    func join() async -> ExpenseGroup? {
        isJoining = true
        defer { isJoining = false }
        do {
            let group = try await groupRepository.joinGroup(inviteCode: inviteCode, user: currentUser)
            errorMessage = nil
            return group
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            return nil
        } catch {
            errorMessage = AppError.saveFailed.localizedDescription
            return nil
        }
    }
}
