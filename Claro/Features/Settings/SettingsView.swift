import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self)        private var appSettings
    @Environment(PermissionsService.self) private var permissions
    @Environment(StoreKitService.self)    private var store

    @State private var showPaywall         = false
    @State private var showAppearance      = false
    @State private var showLanguage        = false
    @State private var showTerms           = false
    @State private var showPrivacy         = false
    @State private var showRestoreAlert    = false
    @State private var restoreAlertMessage = ""
    @State private var isRestoring         = false
    @State private var showNotifInfo       = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ClaroSpacing.lg) {

                        // Hide upsell banner when user is already Pro
                        if !store.isPro {
                            UpsellBanner { showPaywall = true }
                                .padding(.horizontal)
                        }

                        // ── Account ──────────────────────────────────
                        SettingsGroup(label: "Account") {
                            ClaroSettingsRow(
                                icon: "arrow.clockwise.circle.fill",
                                iconColor: .claroVioletLight,
                                title: "Restore Purchase",
                                isLoading: isRestoring
                            ) {
                                Task { await restorePurchases() }
                            }
                        }

                        // ── App Settings ──────────────────────────────
                        SettingsGroup(label: "App Settings") {
                            ClaroSettingsRow(
                                icon: "sun.max.fill",
                                iconColor: .claroCyan,
                                title: "Appearance",
                                value: appSettings.colorSchemePreference.label
                            ) { showAppearance = true }

                            rowDivider()

                            ClaroSettingsRow(
                                icon: "globe",
                                iconColor: .claroVioletLight,
                                title: "Language",
                                value: supportedLanguages.first(where: { $0.id == appSettings.languageCode })?.localName ?? "English"
                            ) { showLanguage = true }

                            rowDivider()

                            ClaroSettingsRow(
                                icon: "bell.badge.fill",
                                iconColor: .claroGold,
                                title: "Notifications",
                                value: permissions.notificationStatus.label
                            ) {
                                Task { await handleNotifications() }
                            }

                            // Brief explanation of what gets notified
                            if permissions.notificationStatus == .authorized ||
                               permissions.notificationStatus == .provisional {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.claroTextMuted)
                                    Text("Weekly scan reminder · Storage full alert")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.claroTextMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }
                        }

                        // ── Help & Feedback ───────────────────────────
                        SettingsGroup(label: "Help & Feedback") {
                            ClaroSettingsRow(
                                icon: "message.fill",
                                iconColor: .claroSuccess,
                                title: "Contact Us"
                            ) { openMail() }

                            rowDivider()

                            ClaroSettingsRow(
                                icon: "star.fill",
                                iconColor: .claroWarning,
                                title: "Rate Claro"
                            ) { rateApp() }

                            rowDivider()

                            // ShareLink — native iOS share sheet
                            ShareLink(
                                item: URL(string: "https://apps.apple.com/app/claro")!,
                                message: Text("Check out Claro — AI Storage Cleaner!")
                            ) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(Color.claroViolet.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.claroVioletLight)
                                    }
                                    Text("Share Claro")
                                        .font(.claroHeadline())
                                        .foregroundStyle(Color.claroTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.claroTextMuted.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                        }

                        // ── Legal ──────────────────────────────────────
                        SettingsGroup(label: "Legal") {
                            ClaroSettingsRow(
                                icon: "doc.text.fill",
                                iconColor: .claroTextMuted,
                                title: "Terms of Service"
                            ) { showTerms = true }

                            rowDivider()

                            ClaroSettingsRow(
                                icon: "lock.fill",
                                iconColor: .claroTextMuted,
                                title: "Privacy Policy"
                            ) { showPrivacy = true }
                        }

                        Text("Claro v1.0.0")
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroTextMuted)
                            .padding(.bottom, ClaroSpacing.xxl)
                    }
                    .padding(.top, ClaroSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
            // Sheets
            .sheet(isPresented: $showPaywall)    { PaywallView() }
            .sheet(isPresented: $showAppearance) { AppearancePickerView() }
            .sheet(isPresented: $showLanguage)   { LanguagePickerView() }
            .sheet(isPresented: $showTerms)   { LegalView(type: .terms).environment(appSettings) }
            .sheet(isPresented: $showPrivacy)  { LegalView(type: .privacy).environment(appSettings) }
            // Alerts
            .alert("Restore Purchase", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreAlertMessage)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rowDivider() -> some View {
        Divider()
            .background(Color.claroCardBorder)
            .padding(.leading, 60)
    }

    // MARK: - Actions

    @MainActor
    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await store.restore()
            restoreAlertMessage = store.isPro
                ? "Your purchases have been successfully restored."
                : "No purchases were found for your Apple ID."
        } catch {
            restoreAlertMessage = "Restore failed. Please try again."
        }
        showRestoreAlert = true
    }

    @MainActor
    private func handleNotifications() async {
        switch permissions.notificationStatus {
        case .notDetermined:
            await permissions.requestNotificationAccess(languageCode: appSettings.languageCode)
        default:
            permissions.openSettings()
        }
    }

    @MainActor
    private func openMail() {
        guard let url = URL(string: "mailto:sameskapple@gmail.com") else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func rateApp() {
        // Replace YOUR_APP_STORE_ID with the numeric ID from App Store Connect
        let appStoreID = "YOUR_APP_STORE_ID"
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Upsell Banner

struct UpsellBanner: View {
    var action: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A0A3E"), Color(hex: "#0D1B4E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.claroViolet.opacity(0.4))
                .frame(width: 120, height: 120)
                .blur(radius: 45)
                .offset(x: 60, y: -30)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.claroGold)
                        Text("Upgrade to Pro")
                            .font(.claroHeadline())
                            .foregroundStyle(Color.white)
                    }
                    Text("Unlock all premium features")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.65))
                }
                Spacer()
                Button(action: action) {
                    Text("Get Pro")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color.claroViolet, Color(hex: "#6D28D9")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .claroGlowShadow()
                }
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroViolet.opacity(0.3), lineWidth: 1)
        )
        .frame(height: 80)
    }
}

// MARK: - Settings Group

struct SettingsGroup<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            ClaroSectionLabel(title: label)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(Color.claroCardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

#Preview { SettingsView() }
