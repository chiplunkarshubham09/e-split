import Foundation

enum MoneyFormatter {
    static func string(from amount: Decimal, currencyCode: String = AppStrings.defaultCurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func compact(from amount: Decimal, currencyCode: String = AppStrings.defaultCurrencyCode) -> String {
        string(from: amount.roundedToMoney, currencyCode: currencyCode)
    }
}
