import SwiftUI

struct SettlementsView: View {
    @State private var viewModel: SettlementsViewModel

    init(viewModel: SettlementsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section { ErrorBanner(message: errorMessage) }
            }

            Section("Record a settlement") {
                if viewModel.availableDebts.isEmpty {
                    Text("Everyone is currently settled.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    ForEach(viewModel.availableDebts) { debt in
                        HStack {
                            Text(sentence(for: debt))
                            Spacer()
                            Button("Record") {
                                Task { await viewModel.record(debt) }
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.primary)
                            .disabled(viewModel.isSaving)
                        }
                    }
                }
            }

            Section("Pending") {
                if pendingSettlements.isEmpty {
                    Text("No pending settlements.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    ForEach(pendingSettlements) { settlement in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.description(for: settlement))
                            Button("Mark as Paid") {
                                Task { await viewModel.markPaid(settlement) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.primary)
                            .disabled(viewModel.isSaving)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Paid") {
                if paidSettlements.isEmpty {
                    Text("No settlements yet.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    ForEach(paidSettlements) { settlement in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.description(for: settlement))
                            Text("Status: Paid")
                                .font(.caption)
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas)
        .navigationTitle("Settlements")
        .animation(.snappy, value: viewModel.settlements.count)
        .animation(.snappy, value: pendingSettlements.map(\.id))
        .task {
            await viewModel.reload()
        }
    }

    private var pendingSettlements: [Settlement] {
        viewModel.settlements.filter { $0.status == .pending }
    }

    private var paidSettlements: [Settlement] {
        viewModel.settlements.filter { $0.status == .paid }
    }

    private func sentence(for debt: Debt) -> String {
        let amount = MoneyFormatter.compact(from: debt.amount, currencyCode: viewModel.group.currency)
        let from = viewModel.group.displayName(for: debt.fromUserId, currentUserID: viewModel.currentUserID)
        let to = viewModel.group.displayName(for: debt.toUserId, currentUserID: viewModel.currentUserID)
        return "\(from) owes \(to) \(amount)"
    }
}
