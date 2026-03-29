import Photos
import Contacts
import UserNotifications
import UIKit
import Observation

@Observable
final class PermissionsService {

    var photoStatus: PHAuthorizationStatus = .notDetermined
    var contactStatus: CNAuthorizationStatus = .notDetermined
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    init() { refresh() }

    // MARK: - Refresh

    func refresh() {
        photoStatus   = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        contactStatus = CNContactStore.authorizationStatus(for: .contacts)
        Task { @MainActor in
            let s = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = s.authorizationStatus
        }
    }

    // MARK: - Photo Access

    @MainActor
    func requestPhotoAccess() async {
        photoStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: - Contact Access

    @MainActor
    func requestContactAccess() async {
        do {
            let granted = try await CNContactStore().requestAccess(for: .contacts)
            contactStatus = granted ? .authorized : .denied
        } catch {
            contactStatus = .denied
        }
    }

    // MARK: - Notifications

    @MainActor
    func requestNotificationAccess(languageCode: String = "en") async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                // Schedule weekly reminder the moment permission is granted
                NotificationService.shared.scheduleWeeklyReminder(languageCode: languageCode)
            }
        } catch {}
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = s.authorizationStatus
    }

    // MARK: - Open Settings

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Convenience

extension PHAuthorizationStatus {
    var isGranted: Bool { self == .authorized || self == .limited }
    var isDenied:  Bool { self == .denied || self == .restricted }
}

extension CNAuthorizationStatus {
    var isGranted: Bool { self == .authorized }
    var isDenied:  Bool { self == .denied || self == .restricted }
}

extension UNAuthorizationStatus {
    /// Returns a key present in both Localizable.strings files.
    var label: String {
        switch self {
        case .authorized, .provisional, .ephemeral: return "Enabled"
        case .denied:        return "Disabled"
        case .notDetermined: return "Not Set"
        @unknown default:    return ""
        }
    }
}
