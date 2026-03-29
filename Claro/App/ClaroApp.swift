import SwiftUI

@main
struct ClaroApp: App {
    @State private var appSettings      = AppSettings()
    @State private var permissions      = PermissionsService()
    @State private var store            = StoreKitService()
    @State private var photoService     = DuplicatePhotoService()
    @State private var iCloudService    = ICloudService()
    @State private var contactService   = ContactService()
    @State private var vaultService     = VaultService()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Changing languageChangeID recreates the whole hierarchy so
                // Text() picks up the new Localizable.strings immediately.
                .id(appSettings.languageChangeID)
                // Services available everywhere via @Environment
                .environment(appSettings)
                .environment(permissions)
                .environment(store)
                .environment(photoService)
                .environment(iCloudService)
                .environment(contactService)
                .environment(vaultService)
                // Load StoreKit products + entitlements after first frame — keeps launch instant
                .task {
                    async let products: () = store.loadProducts()
                    async let entitlements: () = store.refreshEntitlements()
                    _ = await (products, entitlements)
                }
                // Apply chosen colour scheme — reacts immediately via @Observable
                .preferredColorScheme(appSettings.preferredColorScheme)
                // Apply chosen language/locale to all Text + date/number formatters
                .environment(\.locale, appSettings.locale)
                // RTL support: flips layout direction for Hebrew automatically
                .environment(\.layoutDirection, appSettings.languageCode == "he" ? .rightToLeft : .leftToRight)
        }
    }
}
