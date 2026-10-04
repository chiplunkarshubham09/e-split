import SwiftUI

struct ExpenseHistoryView: View {
    @Environment(\.dependencies) private var dependencies
    @Bindable var viewModel: ExpenseHistoryViewModel
    @State private var showFilters = false

    var body: some View {
        List {
            if viewModel.filteredExpenses.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matching expenses",
                    message: "Try a different search or clear the filters."
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredExpenses) { expense in
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
                            paidByName: viewModel.group.displayName(
                                for: expense.paidBy,
                                currentUserID: viewModel.currentUserID
                            ),
                            currencyCode: viewModel.group.currency
                        )
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas)
        .navigationTitle("Expenses")
        .searchable(text: $viewModel.searchText, prompt: "Search expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Filters") { showFilters = true }
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                Form {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("All").tag(Optional<ExpenseCategory>.none)
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.title).tag(Optional(category))
                        }
                    }
                    Picker("Member", selection: $viewModel.selectedMemberID) {
                        Text("Anyone").tag(Optional<UUID>.none)
                        ForEach(viewModel.group.members) { member in
                            Text(viewModel.group.displayName(for: member.userId, currentUserID: viewModel.currentUserID))
                                .tag(Optional(member.userId))
                        }
                    }
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { viewModel.startDate ?? Date() },
                            set: { viewModel.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Toggle("Use start date", isOn: Binding(
                        get: { viewModel.startDate != nil },
                        set: { viewModel.startDate = $0 ? (viewModel.startDate ?? Date()) : nil }
                    ))
                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { viewModel.endDate ?? Date() },
                            set: { viewModel.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Toggle("Use end date", isOn: Binding(
                        get: { viewModel.endDate != nil },
                        set: { viewModel.endDate = $0 ? (viewModel.endDate ?? Date()) : nil }
                    ))
                    TextField("Min amount", text: $viewModel.minAmountText)
                        .keyboardType(.decimalPad)
                    TextField("Max amount", text: $viewModel.maxAmountText)
                        .keyboardType(.decimalPad)
                }
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showFilters = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") {
                            viewModel.selectedCategory = nil
                            viewModel.selectedMemberID = nil
                            viewModel.startDate = nil
                            viewModel.endDate = nil
                            viewModel.minAmountText = ""
                            viewModel.maxAmountText = ""
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
