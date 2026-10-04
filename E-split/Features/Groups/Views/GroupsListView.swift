import SwiftUI

struct GroupsListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: GroupsListViewModel
    @State private var path: [UUID] = []
    @Binding var pendingInviteCode: String?
    @Binding var joinedGroupID: UUID?

    init(
        viewModel: GroupsListViewModel,
        pendingInviteCode: Binding<String?> = .constant(nil),
        joinedGroupID: Binding<UUID?> = .constant(nil)
    ) {
        _viewModel = State(initialValue: viewModel)
        _pendingInviteCode = pendingInviteCode
        _joinedGroupID = joinedGroupID
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.groups.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        systemImage: "person.3",
                        title: "No Groups Yet",
                        message: "Create a group or join one with an invite link.",
                        actionTitle: "Create Group"
                    ) {
                        viewModel.showCreateGroup = true
                    }
                } else {
                    List {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        Section("Your groups") {
                            ForEach(viewModel.groups) { group in
                                NavigationLink(value: group.id) {
                                    GroupRowView(group: group)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .background(AppTheme.canvas)
            .navigationTitle("Groups")
            .toolbarBackground(AppTheme.canvas, for: .navigationBar)
            .navigationDestination(for: UUID.self) { groupID in
                GroupDestinationView(groupID: groupID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ProfileView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Your profile")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Create Group", systemImage: "plus") {
                            viewModel.showCreateGroup = true
                        }
                        Button("Join with code", systemImage: "link") {
                            viewModel.showJoinByCode = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
            .sheet(isPresented: $viewModel.showCreateGroup) {
                CreateGroupView(
                    viewModel: CreateGroupViewModel(
                        repository: dependencies.groupRepository,
                        currentUser: dependencies.authRepository.currentUser
                    )
                ) { created in
                    Task {
                        await viewModel.load()
                        path.append(created.id)
                    }
                }
            }
            .alert("Join with invite code", isPresented: $viewModel.showJoinByCode) {
                TextField("Invite code", text: $viewModel.joinCode)
                    .textInputAutocapitalization(.characters)
                Button("Join") {
                    pendingInviteCode = InviteCode.normalized(viewModel.joinCode)
                    viewModel.joinCode = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.joinCode = ""
                }
            } message: {
                Text("Paste the code from an invite link.")
            }
            .task {
                await viewModel.load()
                await dependencies.notificationService.requestAuthorization()
            }
            .onChange(of: path) { _, newPath in
                if newPath.isEmpty {
                    Task { await viewModel.load() }
                }
            }
            .onChange(of: joinedGroupID) { _, groupID in
                if let groupID {
                    path.append(groupID)
                    joinedGroupID = nil
                    Task { await viewModel.load() }
                }
            }
        }
    }
}

private struct GroupDestinationView: View {
    @Environment(\.dependencies) private var dependencies
    let groupID: UUID
    @State private var viewModel: GroupDashboardViewModel?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let viewModel {
                GroupDashboardView(viewModel: viewModel)
            } else if loadFailed {
                ContentUnavailableView("Group unavailable", systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                guard let group = try await dependencies.groupRepository.fetchGroup(id: groupID) else {
                    loadFailed = true
                    return
                }
                viewModel = GroupDashboardViewModel(
                    group: group,
                    groupRepository: dependencies.groupRepository,
                    expenseRepository: dependencies.expenseRepository,
                    settlementRepository: dependencies.settlementRepository,
                    currentUserID: dependencies.authRepository.currentUser.id
                )
            } catch {
                loadFailed = true
            }
        }
    }
}

private struct GroupRowView: View {
    let group: ExpenseGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: group.type?.systemImage ?? "person.3.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.onPrimary)
                .frame(width: 44, height: 44)
                .background(AppTheme.primary.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondary)
                Text("\(group.members.count) members · \(group.currency)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Bindable var viewModel: GroupsListViewModel

    var body: some View {
        Form {
            Section("Account") {
                TextField("Your name", text: $viewModel.yourName)
                    .textInputAutocapitalization(.words)
                LabeledContent("Email", value: viewModel.currentUser.email)
            }
            Section {
                Button("Save name") {
                    viewModel.saveName()
                }
            } footer: {
                Text("Your name is used on expenses, balances, and group invites.")
            }
            Section {
                Button("Sign out", role: .destructive) {
                    dependencies.authRepository.logout()
                }
            }
        }
        .navigationTitle("Profile")
    }
}
