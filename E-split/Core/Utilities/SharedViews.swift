import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(AppTheme.primary)
        } description: {
            Text(message)
                .foregroundStyle(AppTheme.secondary)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    var tint: Color = AppTheme.primary
    var usesPrimaryFill = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(usesPrimaryFill ? AppTheme.onPrimary.opacity(0.85) : AppTheme.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(usesPrimaryFill ? AppTheme.onPrimary : tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            usesPrimaryFill ? AppTheme.primary : AppTheme.cardFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(usesPrimaryFill ? Color.clear : AppTheme.cardStroke, lineWidth: 1)
        )
    }
}

struct CategoryIconView: View {
    let category: ExpenseCategory

    var body: some View {
        Image(systemName: category.systemImage)
            .font(.headline)
            .foregroundStyle(AppTheme.onPrimary)
            .frame(width: 40, height: 40)
            .background(category.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    let paidByName: String
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: expense.category)
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondary)
                Text("Paid by \(paidByName) · \(expense.createdAt.relativeOrDateString)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary.opacity(0.8))
            }
            Spacer()
            Text(MoneyFormatter.compact(from: expense.amount, currencyCode: currencyCode))
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppTheme.onPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(hex: 0x8A3A3A).gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
