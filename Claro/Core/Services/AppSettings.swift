import SwiftUI
import Observation

@Observable
final class AppSettings {

    var colorSchemePreference: ColorSchemePreference
    var languageCode:          String
    /// Changing this ID forces ClaroApp to recreate the entire view hierarchy,
    /// making the new language take effect immediately without an app restart.
    var languageChangeID:      UUID = UUID()

    // MARK: - Init

    init() {
        let savedScheme  = UserDefaults.standard.string(forKey: "claro_colorScheme") ?? "dark"
        colorSchemePreference = ColorSchemePreference(rawValue: savedScheme) ?? .dark

        let deviceLang   = Locale.current.language.languageCode?.identifier ?? "en"
        languageCode     = UserDefaults.standard.string(forKey: "claro_language") ?? deviceLang
    }

    // MARK: - Computed

    var preferredColorScheme: ColorScheme? { colorSchemePreference.scheme }
    var locale: Locale { Locale(identifier: languageCode) }

    // MARK: - Setters

    func setColorScheme(_ pref: ColorSchemePreference) {
        colorSchemePreference = pref
        UserDefaults.standard.set(pref.rawValue, forKey: "claro_colorScheme")
        // .preferredColorScheme in ClaroApp reacts immediately — no ID change needed
    }

    func setLanguage(_ code: String) {
        languageCode = code
        UserDefaults.standard.set(code, forKey: "claro_language")
        // Tell the OS which language to use for bundle-based string lookups
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        // Trigger full view-hierarchy recreation so Text() picks up the new strings
        languageChangeID = UUID()
    }

    // MARK: - Types

    enum ColorSchemePreference: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var scheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }

        /// Returns a key that exists in both Localizable.strings files.
        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light:  return "sun.max.fill"
            case .dark:   return "moon.stars.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .system: return .claroTextSecondary
            case .light:  return .claroGold
            case .dark:   return .claroViolet
            }
        }
    }
}
