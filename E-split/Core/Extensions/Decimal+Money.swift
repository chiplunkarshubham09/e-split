import Foundation

extension Decimal {
    static let moneyZero: Decimal = 0

    var roundedToMoney: Decimal {
        MoneyRounding.round(self)
    }

    var isMoneyZero: Bool {
        roundedToMoney == .moneyZero
    }

    var isStrictlyPositive: Bool {
        self > 0
    }
}

enum MoneyRounding {
    static let scale: Int = 2

    static func round(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    static func toMinorUnits(_ value: Decimal) -> Int {
        let scaled = round(value * 100)
        return NSDecimalNumber(decimal: scaled).intValue
    }

    static func fromMinorUnits(_ units: Int) -> Decimal {
        round(Decimal(units) / 100)
    }
}
