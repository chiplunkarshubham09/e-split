import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var pendingInviteCode: String?
    @State private var joinedGroupID: UUID?

    var body: some View {
        Group {
            if dependencies.authRepository.isLoggedIn {
                GroupsListView(
                    viewModel: GroupsListViewModel(
                        repository: dependencies.groupRepository,
                        currentUserStore: dependencies.authRepository
                    ),
                    pendingInviteCode: $pendingInviteCode,
                    joinedGroupID: $joinedGroupID
                )
            } else {
                LoginView(viewModel: AuthViewModel(auth: dependencies.authRepository))
            }
        }
        .onOpenURL { url in
            pendingInviteCode = InviteCode.parse(url)
        }
        .sheet(item: inviteSheetItem) { item in
            JoinGroupView(
                viewModel: JoinGroupViewModel(
                    inviteCode: item.code,
                    groupRepository: dependencies.groupRepository,
                    currentUser: dependencies.authRepository.currentUser
                )
            ) { group in
                pendingInviteCode = nil
                joinedGroupID = group.id
            }
        }
    }

    private var inviteSheetItem: Binding<InviteSheetItem?> {
        Binding(
            get: {
                guard dependencies.authRepository.isLoggedIn, let code = pendingInviteCode else {
                    return nil
                }
                return InviteSheetItem(code: code)
            },
            set: { newValue in
                if newValue == nil {
                    pendingInviteCode = nil
                }
            }
        )
    }
}

private struct InviteSheetItem: Identifiable {
    var id: String { code }
    let code: String
}
