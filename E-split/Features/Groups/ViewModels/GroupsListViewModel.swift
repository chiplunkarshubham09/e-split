import Foundation

@Observable
final class GroupsListViewModel {
    var groups: [ExpenseGroup] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateGroup = false
    var showJoinByCode = false
    var joinCode = ""
    var yourName: String

    private let repository: GroupRepositoryProtocol
    private let currentUserStore: CurrentUserProviding

    var currentUser: CurrentUser { currentUserStore.currentUser }

    init(repository: GroupRepositoryProtocol, currentUserStore: CurrentUserProviding) {
        self.repository = repository
        self.currentUserStore = currentUserStore
        self.yourName = currentUserStore.currentUser.name
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userID = currentUserStore.currentUser.id
            groups = try await repository.fetchGroups(includeArchived: false)
                .filter { $0.members.contains { $0.userId == userID } }
            errorMessage = nil
        } catch {
            errorMessage = AppError.loadFailed.localizedDescription
        }
    }

    func saveName() {
        currentUserStore.updateName(yourName)
    }
}
