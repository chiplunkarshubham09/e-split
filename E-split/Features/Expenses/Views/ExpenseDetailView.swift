import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: ExpenseDetailViewModel
    @State private var editExpenseForm: AddExpenseViewModel?

    init(viewModel: ExpenseDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section { ErrorBanner(message: errorMessage) }
            }

            Section {
                HStack {
                    CategoryIconView(category: viewModel.expense.category)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.expense.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.secondary)
                        Text(MoneyFormatter.compact(from: viewModel.expense.amount, currencyCode: viewModel.group.currency))
                            .font(.title.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Paid by") {
                Text(viewModel.group.displayName(for: viewModel.expense.paidBy, currentUserID: viewModel.currentUserID))
            }

            Section("Split") {
                ForEach(viewModel.expense.splits) { split in
                    HStack {
                        Text(viewModel.group.displayName(for: split.userId, currentUserID: viewModel.currentUserID))
                        Spacer()
                        Text(MoneyFormatter.compact(from: split.amount, currencyCode: viewModel.group.currency))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }

            Section("Details") {
                LabeledContent("Category", value: viewModel.expense.category.title)
                LabeledContent("Date", value: viewModel.expense.createdAt.expenseDisplayString)
                LabeledContent("Split method", value: viewModel.expense.splitMethod.title)
                if !viewModel.expense.notes.isEmpty {
                    LabeledContent("Notes", value: viewModel.expense.notes)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas)
        .navigationTitle("Expense")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        presentEdit()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        viewModel.confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editExpenseForm, onDismiss: {
            Task { await viewModel.reload() }
        }) { form in
            AddExpenseView(viewModel: form)
        }
        .confirmationDialog("Delete this expense?", isPresented: $viewModel.confirmDelete, titleVisibility: .visible) {
            Button("Delete Expense", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Balances will be recalculated after this expense is removed.")
        }
    }

    private func presentEdit() {
        editExpenseForm = AddExpenseViewModel(
            group: viewModel.group,
            existing: viewModel.expense,
            expenseRepository: dependencies.expenseRepository,
            currentUserID: viewModel.currentUserID,
            notificationService: dependencies.notificationService
        )
    }
}
