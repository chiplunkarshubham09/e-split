import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddExpenseViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section { ErrorBanner(message: errorMessage) }
                }

                Section("Expense") {
                    TextField("Description", text: $viewModel.title)
                    TextField("Amount", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    DatePicker("Date", selection: $viewModel.createdAt, displayedComponents: .date)
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                }

                Section("Paid by") {
                    Picker("Paid by", selection: $viewModel.paidBy) {
                        ForEach(viewModel.group.members) { member in
                            Text(name(for: member.userId)).tag(member.userId)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Split method") {
                    Picker("Split method", selection: $viewModel.splitMethod) {
                        ForEach(SplitMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Text(viewModel.splitMethod.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }

                Section("Split between") {
                    ForEach($viewModel.participants) { $participant in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(name(for: participant.member.userId), isOn: $participant.isSelected)
                            if participant.isSelected {
                                switch viewModel.splitMethod {
                                case .equal:
                                    EmptyView()
                                case .exactAmount:
                                    TextField("Amount", text: $participant.exactAmount)
                                        .keyboardType(.decimalPad)
                                case .percentage:
                                    TextField("Percent", text: $participant.percentage)
                                        .keyboardType(.decimalPad)
                                case .shares:
                                    TextField("Shares", text: $participant.shares)
                                        .keyboardType(.decimalPad)
                                }
                            }
                        }
                    }
                }

                if !viewModel.previewSplits.isEmpty {
                    Section("Split preview") {
                        ForEach(viewModel.previewSplits, id: \.userId) { split in
                            HStack {
                                Text(name(for: split.userId))
                                Spacer()
                                Text(MoneyFormatter.compact(from: split.amount, currencyCode: viewModel.group.currency))
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private func name(for userId: UUID) -> String {
        viewModel.group.displayName(for: userId, currentUserID: viewModel.currentUserID)
    }
}
