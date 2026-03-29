import UserNotifications
import Foundation

/// Schedules and manages all Claro notifications.
/// Called by PermissionsService after notification access is granted.
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // Notification identifiers
    private let weeklyReminderID  = "claro.weekly-reminder"
    private let storageWarningID  = "claro.storage-warning"

    // MARK: - Weekly Scan Reminder
    // Fires every Sunday at 10:00 AM.

    func scheduleWeeklyReminder(languageCode: String) {
        cancelWeeklyReminder()

        let isHebrew = languageCode == "he"
        let content  = UNMutableNotificationContent()

        content.title = isHebrew
            ? "זמן לנקות 📱"
            : "Time to Clean 📱"
        content.body  = isHebrew
            ? "האחסון שלך גדל השבוע. הקש לסריקה חכמה עם Claro."
            : "Your storage has grown this week. Tap for a smart scan with Claro."
        content.sound = .default

        var comps        = DateComponents()
        comps.weekday    = 1   // Sunday
        comps.hour       = 10
        comps.minute     = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: weeklyReminderID,
            content:    content,
            trigger:    trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklyReminderID])
    }

    // MARK: - Storage Warning
    // Fires once when device storage exceeds 85%.

    func scheduleStorageWarningIfNeeded(usedPercent: Double, languageCode: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [storageWarningID])

        guard usedPercent >= 0.85 else { return }

        let isHebrew = languageCode == "he"
        let pct      = Int(usedPercent * 100)
        let content  = UNMutableNotificationContent()

        content.title = isHebrew
            ? "האחסון כמעט מלא ⚠️"
            : "Storage Almost Full ⚠️"
        content.body  = isHebrew
            ? "הטלפון שלך \(pct)% מלא. פתח את Claro כדי לנקות."
            : "Your phone is \(pct)% full. Open Claro to clean up."
        content.sound = .defaultCritical

        // Fire after a short delay (not immediately, to avoid spamming on launch)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false)
        let request = UNNotificationRequest(
            identifier: storageWarningID,
            content:    content,
            trigger:    trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel all

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
