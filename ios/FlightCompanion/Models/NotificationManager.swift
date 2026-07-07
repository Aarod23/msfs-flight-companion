import UserNotifications

class NotificationManager {
    func send(title: String, body: String, delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[Notification] Error: \(error)") }
        }
    }

    func scheduleArrivalAlert(eta: Date) {
        let alertTime = eta.addingTimeInterval(-1800) // 30 min before
        guard alertTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏰ Approaching Destination"
        content.body = "Landing in approximately 30 minutes"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "arrival-alert", content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["arrival-alert"])
        UNUserNotificationCenter.current().add(request)
    }
}
