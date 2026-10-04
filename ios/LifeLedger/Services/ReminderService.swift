import Foundation
import UserNotifications

enum ReminderService {
    static func schedule(hour: Int, minute: Int, zh: Bool) async throws {
        let center = UNUserNotificationCenter.current()
        let allowed = try await center.requestAuthorization(options: [.alert, .sound])
        guard allowed else { throw NSError(domain: "LifeLedger", code: 1, userInfo: [NSLocalizedDescriptionKey: zh ? "请在系统设置中允许人生账本发送通知" : "Allow notifications for LifeLedger in Settings"]) }
        let content = UNMutableNotificationContent()
        content.title = zh ? "今天也值得被记住" : "Today is worth remembering"
        content.body = zh ? "记录一个小小的成就，看看自己走过的路。" : "Record a small achievement and celebrate how far you've come."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try await center.add(UNNotificationRequest(identifier: "lifeledger-daily", content: content, trigger: trigger))
    }
    static func cancel() async { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["lifeledger-daily"]) }
}
