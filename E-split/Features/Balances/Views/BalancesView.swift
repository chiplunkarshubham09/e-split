import SwiftUI

struct BalancesView: View {
    var viewModel: BalancesViewModel

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section { ErrorBanner(message: errorMessage) }
            }

            Section("You") {
                LabeledContent("You Owe") {
                    Text(MoneyFormatter.compact(from: viewModel.youOwe, currencyCode: viewModel.group.currency))
                        .foregroundStyle(AppTheme.owe)
                        .fontWeight(.semibold)
                }
                LabeledContent("You Are Owed") {
                    Text(MoneyFormatter.compact(from: viewModel.youAreOwed, currencyCode: viewModel.group.currency))
                        .foregroundStyle(AppTheme.owed)
                        .fontWeight(.semibold)
                }
            }

            Section("Who owes whom") {
                if viewModel.debts.isEmpty {
                    Text("Everyone is currently settled.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    ForEach(viewModel.debts) { debt in
                        Text(viewModel.sentence(for: debt))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas)
        .navigationTitle("Balances")
    }
}
