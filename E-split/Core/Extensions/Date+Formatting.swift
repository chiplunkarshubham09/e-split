import Foundation

extension Date {
    var expenseDisplayString: String {
        formatted(date: .long, time: .omitted)
    }

    var relativeOrDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }
        return formatted(date: .abbreviated, time: .omitted)
    }
}
