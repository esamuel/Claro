import SwiftUI

struct EmailCleanerView: View {
    @State private var service = EmailCleanerService()
    @State private var signInError: String?
    @State private var showError     = false
    @State private var isSigningIn   = false

    var body: some View {
        ZStack {
            Color.claroBg.ignoresSafeArea()

            if service.isAuthenticated {
                EmailCleanerConnectedView(service: service)
            } else {
                connectScreen
            }
        }
        .navigationTitle("Email Cleaner")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign-In Failed", isPresented: $showError) {
            Button("OK") { signInError = nil }
        } message: { Text(signInError ?? "") }
    }

    // MARK: - Connect Screen

    private var connectScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                FloatingEmailIcon(size: 26, offset: CGPoint(x: -110, y: -55), opacity: 0.35)
                FloatingEmailIcon(size: 20, offset: CGPoint(x: -70,  y:  65), opacity: 0.25)
                FloatingEmailIcon(size: 18, offset: CGPoint(x:  90,  y: -80), opacity: 0.30)
                FloatingEmailIcon(size: 24, offset: CGPoint(x: 115,  y:  20), opacity: 0.45)
                FloatingEmailIcon(size: 16, offset: CGPoint(x:  20,  y:  90), opacity: 0.20)
                FloatingEmailIcon(size: 14, offset: CGPoint(x: -30,  y: -95), opacity: 0.18)

                ZStack {
                    Circle()
                        .fill(Color.claroSuccess)
                        .frame(width: 110, height: 110)
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 220)

            VStack(spacing: ClaroSpacing.sm) {
                Text("Clean your inbox")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Connect Gmail to find newsletters, promotions, and social clutter — then delete them all at once.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, ClaroSpacing.xl)

            Spacer()

            VStack(spacing: ClaroSpacing.md) {
                // Privacy note
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.claroSuccess.opacity(0.8))
                        .padding(.top, 1)
                    Text("Claro only reads message IDs and labels to count and delete emails. It never reads your email content or stores your credentials.")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextSecondary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(Color.claroCard)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: ClaroRadius.sm)
                    .strokeBorder(Color.claroSuccess.opacity(0.2), lineWidth: 1))
                .padding(.horizontal)

                // Sign in button
                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 10) {
                        if isSigningIn {
                            ProgressView().tint(Color.claroTextPrimary).scaleEffect(0.85)
                        } else {
                            GoogleLogoView()
                                .frame(width: 20, height: 20)
                        }
                        Text(isSigningIn ? "Connecting…" : "Sign in with Google")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.claroTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.claroCard)
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: ClaroRadius.md)
                        .strokeBorder(Color.claroCardBorder, lineWidth: 1.5))
                    .claroCardShadow()
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)
                .padding(.horizontal)
            }
            .padding(.bottom, ClaroSpacing.xl)
        }
    }

    private func signIn() async {
        isSigningIn = true
        do {
            try await service.signIn()
        } catch {
            let msg = error.localizedDescription
            if !msg.lowercased().contains("cancel") {
                signInError = msg
                showError   = true
            }
        }
        isSigningIn = false
    }
}

// MARK: - Connected View

private struct EmailCleanerConnectedView: View {
    @Bindable var service: EmailCleanerService   // @Observable needs @Bindable for mutating via bindings (read-only here is fine too)
    @State private var deleteCategory: String?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ClaroSpacing.lg) {

                headerCard
                    .padding(.horizontal)

                if service.isScanning {
                    scanningState
                } else if service.scanComplete {
                    categoriesSection
                }

                Spacer(minLength: ClaroSpacing.xxl)
            }
            .padding(.top, ClaroSpacing.md)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    service.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.claroDanger)
                }
            }
        }
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                guard let cat = deleteCategory else { return }
                Task { await performDelete(cat) }
            }
            Button("Cancel", role: .cancel) { deleteCategory = nil }
        } message: {
            Text("These emails will be permanently deleted from your Gmail. This cannot be undone.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK") { deleteError = nil }
        } message: { Text(deleteError ?? "") }
    }

    // MARK: - Header card

    private var headerCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A2E1A"), Color(hex: "#0A1628")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.claroSuccess.opacity(0.25))
                .frame(width: 130, height: 130)
                .blur(radius: 60)
                .offset(x: 70, y: -20)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.claroSuccess)
                        Text("Gmail Connected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.claroSuccess)
                    }
                    if let email = service.userEmail {
                        Text(email)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                    }
                    let total = service.newsletters.count + service.promotions.count + service.social.count
                    Text("\(total) emails found to clean")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                Button {
                    Task { await service.scan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.claroTextMuted)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(ClaroSpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: ClaroRadius.lg)
            .strokeBorder(Color.claroSuccess.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Scanning state

    private var scanningState: some View {
        VStack(spacing: ClaroSpacing.md) {
            Spacer(minLength: 40)
            ProgressView()
                .scaleEffect(1.3)
                .tint(Color.claroSuccess)
            Text("Scanning your inbox…")
                .font(.claroBody())
                .foregroundStyle(Color.claroTextSecondary)
            Spacer(minLength: 40)
        }
    }

    // MARK: - Categories section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            ClaroSectionLabel(title: "What we found")
                .padding(.horizontal)

            EmailCategoryRow(
                icon: "envelope.badge.fill",
                color: .claroDanger,
                title: "Newsletters",
                subtitle: subtitle(for: "newsletters"),
                count: service.newsletters.count,
                isDeleting: service.deletingCategory == "newsletters"
            ) {
                deleteCategory   = "newsletters"
                showDeleteConfirm = true
            }
            .padding(.horizontal)

            EmailCategoryRow(
                icon: "tag.fill",
                color: .claroGold,
                title: "Promotions",
                subtitle: subtitle(for: "promotions"),
                count: service.promotions.count,
                isDeleting: service.deletingCategory == "promotions"
            ) {
                deleteCategory   = "promotions"
                showDeleteConfirm = true
            }
            .padding(.horizontal)

            EmailCategoryRow(
                icon: "person.2.fill",
                color: .claroCyan,
                title: "Social",
                subtitle: subtitle(for: "social"),
                count: service.social.count,
                isDeleting: service.deletingCategory == "social"
            ) {
                deleteCategory   = "social"
                showDeleteConfirm = true
            }
            .padding(.horizontal)

            Text("Emails from the last 90 days · Scoped to Inbox")
                .font(.claroLabel())
                .foregroundStyle(Color.claroTextMuted)
                .padding(.horizontal)
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private var deleteConfirmTitle: String {
        guard let cat = deleteCategory else { return "Delete emails?" }
        let count: Int
        switch cat {
        case "newsletters": count = service.newsletters.count
        case "promotions":  count = service.promotions.count
        case "social":      count = service.social.count
        default: count = 0
        }
        return "Delete \(count) \(cat.capitalized)?"
    }

    private func subtitle(for category: String) -> String {
        if service.deletingCategory == category { return "Deleting…" }
        let count: Int
        switch category {
        case "newsletters": count = service.newsletters.count
        case "promotions":  count = service.promotions.count
        case "social":      count = service.social.count
        default: count = 0
        }
        return count == 0 ? "None found · inbox is clean" : "\(count) emails"
    }

    private func performDelete(_ category: String) async {
        do {
            try await service.deleteAll(category: category)
        } catch {
            deleteError     = error.localizedDescription
            showDeleteError = true
        }
    }
}

// MARK: - Category Row

private struct EmailCategoryRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let count: Int
    let isDeleting: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                Text(subtitle)
                    .font(.claroCaption())
                    .foregroundStyle(count == 0 ? Color.claroTextMuted : color)
            }

            Spacer()

            if isDeleting {
                ProgressView()
                    .tint(color)
                    .scaleEffect(0.85)
            } else if count > 0 {
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Delete all")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.claroSuccess.opacity(0.6))
            }
        }
        .padding(14)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(RoundedRectangle(cornerRadius: ClaroRadius.md)
            .strokeBorder(count > 0 ? color.opacity(0.2) : Color.claroCardBorder, lineWidth: 1))
    }
}

// MARK: - Shared helpers

private struct FloatingEmailIcon: View {
    let size: CGFloat
    let offset: CGPoint
    let opacity: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.claroSuccess.opacity(opacity * 0.5))
                .frame(width: size + 10, height: size + 10)
            Image(systemName: "tray.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(Color.claroSuccess.opacity(opacity))
        }
        .offset(x: offset.x, y: offset.y)
    }
}

private struct GoogleLogoView: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 20, height: 20)
            Text("G")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#4285F4"))
        }
    }
}

#Preview { EmailCleanerView() }
