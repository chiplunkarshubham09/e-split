import SwiftUI

struct GroupDashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: GroupDashboardViewModel
    @State private var addExpenseForm: AddExpenseViewModel?

    init(viewModel: GroupDashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                summarySection
                membersSection
                balancesSection
                recentExpensesSection
            }
            .padding()
        }
        .background(AppTheme.canvas)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add Member", systemImage: "person.badge.plus") {
                        viewModel.showAddMember = true
                    }
                    Button("Invite with link", systemImage: "link") {
                        viewModel.showInvite = true
                    }
                    if viewModel.isAdmin {
                        Button("Edit Group", systemImage: "pencil") {
                            viewModel.showEditGroup = true
                        }
                        Button("Archive Group", systemImage: "archivebox") {
                            Task {
                                await viewModel.archiveGroup()
                                dismiss()
                            }
                        }
                        Button("Delete Group", systemImage: "trash", role: .destructive) {
                            viewModel.confirmDelete = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                presentAddExpense()
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .padding()
            .background(AppTheme.canvas)
        }
        .sheet(isPresented: $viewModel.showAddMember, onDismiss: reload) {
            AddMemberView(
                viewModel: AddMemberViewModel(
                    repository: dependencies.groupRepository,
                    group: viewModel.group
                )
            )
        }
        .sheet(isPresented: $viewModel.showInvite, onDismiss: reload) {
            InviteMembersView(
                viewModel: InviteMembersViewModel(
                    group: viewModel.group,
                    repository: dependencies.groupRepository
                )
            )
        }
        .sheet(item: $addExpenseForm, onDismiss: reload) { form in
            AddExpenseView(viewModel: form)
        }
        .sheet(isPresented: $viewModel.showEditGroup, onDismiss: reload) {
            EditGroupView(
                viewModel: EditGroupViewModel(
                    repository: dependencies.groupRepository,
                    group: viewModel.group
                )
            )
        }
        .confirmationDialog("Delete this group?", isPresented: $viewModel.confirmDelete, titleVisibility: .visible) {
            Button("Delete Group", role: .destructive) {
                Task {
                    await viewModel.deleteGroup()
                    dismiss()
                }
            }
        } message: {
            Text("This removes the group, expenses, and settlements stored on this device.")
        }
        .task { await viewModel.load() }
    }

    private var summarySection: some View {
        let currency = viewModel.group.currency
        return VStack(alignment: .leading, spacing: 12) {
            if !viewModel.group.description.isEmpty {
                Text(viewModel.group.description)
                    .foregroundStyle(AppTheme.secondary)
            }
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Total Expenses",
                    value: MoneyFormatter.compact(from: viewModel.totalExpenses, currencyCode: currency),
                    usesPrimaryFill: true
                )
            }
            HStack(spacing: 12) {
                SummaryCard(
                    title: "You Owe",
                    value: MoneyFormatter.compact(from: viewModel.youOwe, currencyCode: currency),
                    tint: AppTheme.owe
                )
                SummaryCard(
                    title: "You Are Owed",
                    value: MoneyFormatter.compact(from: viewModel.youAreOwed, currencyCode: currency),
                    tint: AppTheme.owed
                )
            }
        }
        .animation(.snappy, value: viewModel.totalExpenses)
    }

    private var membersSection: some View {
        dashboardCard("Members") {
            ForEach(viewModel.group.members) { member in
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(AppTheme.primary)
                    Text(viewModel.group.displayName(for: member.userId, currentUserID: viewModel.currentUserID))
                        .foregroundStyle(AppTheme.secondary)
                    Spacer()
                    Text(member.role.title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            Button("Add Member") {
                viewModel.showAddMember = true
            }
            Button("Invite with link") {
                viewModel.showInvite = true
            }
        }
    }

    private var balancesSection: some View {
        dashboardCard("Current balances") {
            if viewModel.debts.isEmpty {
                Text("Everyone is currently settled.")
                    .foregroundStyle(AppTheme.secondary)
            } else {
                ForEach(viewModel.debts) { debt in
                    Text(balanceSentence(for: debt))
                }
            }
            NavigationLink {
                BalancesView(
                    viewModel: {
                        let vm = BalancesViewModel(group: viewModel.group, currentUserID: viewModel.currentUserID)
                        vm.apply(
                            expenses: viewModel.expenses,
                            settlements: viewModel.settlements,
                            members: viewModel.group.members
                        )
                        return vm
                    }()
                )
            } label: {
                Text("View balances")
            }
            NavigationLink {
                SettlementsView(
                    viewModel: SettlementsViewModel(
                        group: viewModel.group,
                        currentUserID: viewModel.currentUserID,
                        expenseRepository: dependencies.expenseRepository,
                        repository: dependencies.settlementRepository,
                        notificationService: dependencies.notificationService
                    )
                )
            } label: {
                Text("Settlements")
            }
        }
    }

    private var recentExpensesSection: some View {
        dashboardCard("Recent expenses") {
            if viewModel.recentExpenses.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "No Expenses Yet",
                    message: "Start tracking your group expenses.",
                    actionTitle: "Add Expense"
                ) {
                    presentAddExpense()
                }
                .frame(minHeight: 180)
            } else {
                ForEach(viewModel.recentExpenses) { expense in
                    NavigationLink {
                        ExpenseDetailView(
                            viewModel: ExpenseDetailViewModel(
                                expense: expense,
                                group: viewModel.group,
                                currentUserID: viewModel.currentUserID,
                                expenseRepository: dependencies.expenseRepository
                            )
                        )
                    } label: {
                        ExpenseRowView(
                            expense: expense,
                            paidByName: viewModel.group.displayName(for: expense.paidBy, currentUserID: viewModel.currentUserID),
                            currencyCode: viewModel.group.currency
                        )
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink {
                    ExpenseHistoryView(
                        viewModel: ExpenseHistoryViewModel(
                            group: viewModel.group,
                            expenses: viewModel.expenses,
                            currentUserID: viewModel.currentUserID
                        )
                    )
                } label: {
                    Text("See all expenses")
                }
            }
        }
        .animation(.snappy, value: viewModel.expenses.count)
    }

    private func dashboardCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
        )
    }

    private func balanceSentence(for debt: Debt) -> String {
        let amount = MoneyFormatter.compact(from: debt.amount, currencyCode: viewModel.group.currency)
        let from = viewModel.group.displayName(for: debt.fromUserId, currentUserID: viewModel.currentUserID)
        let to = viewModel.group.displayName(for: debt.toUserId, currentUserID: viewModel.currentUserID)
        if debt.toUserId == viewModel.currentUserID {
            return "\(from) owes you \(amount)"
        }
        if debt.fromUserId == viewModel.currentUserID {
            return "You owe \(to) \(amount)"
        }
        return "\(from) owes \(to) \(amount)"
    }

    private func presentAddExpense() {
        addExpenseForm = AddExpenseViewModel(
            group: viewModel.group,
            expenseRepository: dependencies.expenseRepository,
            currentUserID: viewModel.currentUserID,
            notificationService: dependencies.notificationService
        )
    }

    private func reload() {
        Task { await viewModel.load() }
    }
}
