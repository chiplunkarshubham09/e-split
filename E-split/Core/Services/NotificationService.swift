import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorization() async
    func notifyExpenseAdded(title: String, amountText: String, groupName: String) async
    func notifyExpenseUpdated(title: String, groupName: String) async
    func notifySettlementReminder(fromName: String, toName: String, amountText: String) async
}

final class NotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notifyExpenseAdded(title: String, amountText: String, groupName: String) async {
        await schedule(
            identifier: UUID().uuidString,
            title: "Expense added",
            body: "\(title) · \(amountText) in \(groupName)"
        )
    }

    func notifyExpenseUpdated(title: String, groupName: String) async {
        await schedule(
            identifier: UUID().uuidString,
            title: "Expense updated",
            body: "\(title) was updated in \(groupName)"
        )
    }

    func notifySettlementReminder(fromName: String, toName: String, amountText: String) async {
        await schedule(
            identifier: UUID().uuidString,
            title: "Settlement reminder",
            body: "\(fromName) still needs to settle \(amountText) with \(toName)."
        )
    }

    private func schedule(identifier: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        try? await center.add(request)
    }
}
