import SwiftUI
import StoreKit

/// App Store-compliant paywall.
///
/// Optionally accepts real scan results to show impact badges (photos found,
/// GB reclaimable, duplicate contacts). When shown from Settings, pass nothing.
struct PaywallView: View {

    // Optional: pass from scan results for personalised impact display
    var photoDuplicates: Int?    = nil
    var contactDups:     Int?    = nil
    var reclaimableGB:   Double? = nil

    @Environment(\.dismiss)           private var dismiss
    @Environment(StoreKitService.self) private var store
    @Environment(AppSettings.self)    private var appSettings

    @State private var selectedPlan  : PlanType = .annual
    @State private var isPurchasing  = false
    @State private var isRestoring   = false
    @State private var showAlert     = false
    @State private var alertTitle    = ""
    @State private var alertMessage  = ""
    @State private var showTerms     = false
    @State private var showPrivacy   = false

    enum PlanType: String, CaseIterable, Identifiable {
        case annual, lifetime, monthly
        var id: String { rawValue }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.claroBg.ignoresSafeArea()

            // Ambient glow — decorative only
            Circle()
                .fill(Color.claroViolet.opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 110)
                .offset(x: 100, y: -200)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 64)

                    // Show impact cards only when real scan data is available
                    if photoDuplicates != nil || reclaimableGB != nil || contactDups != nil {
                        impactSection
                            .padding(.top, 28)
                    }

                    featuresSection.padding(.top, 28)
                    plansSection.padding(.top, 24)
                    ctaSection.padding(.top, 22)
                    legalSection.padding(.top, 18).padding(.bottom, 52)
                }
                .padding(.horizontal, 20)
            }

            // ── Close button ─────────────────────────────────────────────
            // Must be prominent and easy to find (App Store guideline).
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.claroTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.claroCard)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.claroCardBorder, lineWidth: 1))
            }
            .accessibilityLabel("Close")
            .padding(.top, 16)
            .padding(.trailing, 18)
        }
        .sheet(isPresented: $showTerms)   { LegalView(type: .terms).environment(appSettings) }
        .sheet(isPresented: $showPrivacy)  { LegalView(type: .privacy).environment(appSettings) }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .task { await store.loadProducts() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.claroViolet.opacity(0.35), Color.claroCyan.opacity(0.12)],
                            center: .center, startRadius: 0, endRadius: 52
                        )
                    )
                    .frame(width: 92, height: 92)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.claroGold, Color(hex: "#F97316")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            Text("Claro Pro")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.claroTextPrimary)

            Text("Clean everything. Keep what matters.")
                .font(.claroBody())
                .foregroundStyle(Color.claroTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Impact (personalised when scan results are passed in)

    private var impactSection: some View {
        HStack(spacing: 14) {
            if let photos = photoDuplicates {
                ImpactPill(emoji: "📷", value: "\(photos)", label: "Duplicates",   color: .claroVioletLight)
            }
            if let gb = reclaimableGB {
                ImpactPill(emoji: "💾", value: String(format: "%.1fGB", gb), label: "Reclaimable", color: .claroCyan)
            }
            if let contacts = contactDups {
                ImpactPill(emoji: "📇", value: "\(contacts)", label: "Contacts",     color: .claroSuccess)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features

    private let features: [(icon: String, color: Color, text: LocalizedStringKey)] = [
        ("photo.stack.fill",       .claroVioletLight, "Unlimited duplicate photo cleanup"),
        ("person.2.fill",          .claroCyan,        "Smart contact deduplication"),
        ("icloud.fill",            .claroSuccess,     "iCloud storage analysis"),
        ("lock.shield.fill",       .claroGold,        "Private encrypted vault"),
        ("envelope.badge.fill",    .claroWarning,     "Email breach checker"),
        ("bell.badge.fill",        .claroViolet,      "Weekly smart scan alerts"),
        ("hand.raised.slash.fill", .claroDanger,      "No ads, ever"),
    ]

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, f in
                HStack(spacing: 14) {
                    Image(systemName: f.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(f.color)
                        .frame(width: 30, height: 30)
                        .background(f.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(f.text)
                        .font(.claroBody())
                        .foregroundStyle(Color.claroTextPrimary)

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.claroSuccess)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)

                if index < features.count - 1 {
                    Divider()
                        .background(Color.claroCardBorder)
                        .padding(.leading, 58)
                }
            }
        }
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 10) {
            // Annual first — this is the recommended plan (free trial)
            planCard(
                type:         .annual,
                title:        "Annual",
                displayPrice: store.annualProduct?.displayPrice   ?? "₪79.90",
                per:          "/ year",
                highlight:    "3-day free trial",
                badge:        "Save \(store.annualSavingsPercent)%",
                badgeColor:   .claroViolet
            )
            planCard(
                type:         .lifetime,
                title:        "Lifetime",
                displayPrice: store.lifetimeProduct?.displayPrice ?? "₪149.99",
                per:          "one-time",
                highlight:    nil,
                badge:        "Best Value",
                badgeColor:   .claroGold
            )
            planCard(
                type:         .monthly,
                title:        "Monthly",
                displayPrice: store.monthlyProduct?.displayPrice  ?? "₪14.90",
                per:          "/ month",
                highlight:    nil,
                badge:        nil,
                badgeColor:   .clear
            )

        }
    }

    @ViewBuilder
    private func planCard(
        type:         PlanType,
        title:        LocalizedStringKey,
        displayPrice: String,
        per:          LocalizedStringKey,
        highlight:    LocalizedStringKey?,
        badge:        String?,
        badgeColor:   Color
    ) -> some View {
        let isSelected = selectedPlan == type

        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = type }
        } label: {
            HStack(spacing: 14) {
                // Radio indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.claroViolet : Color.claroTextMuted.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.claroViolet).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.claroHeadline())
                            .foregroundStyle(Color.claroTextPrimary)
                        if let badge {
                            Text(LocalizedStringKey(badge))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(badgeColor)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(badgeColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    if let highlight {
                        Text(highlight)
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroSuccess)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(displayPrice)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.claroTextPrimary)
                    Text(per)
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                }
            }
            .padding(16)
            .background(isSelected ? Color.claroViolet.opacity(0.1) : Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(
                        isSelected ? Color.claroViolet.opacity(0.55) : Color.claroCardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            // Main purchase button
            Button {
                Task { await handlePurchase() }
            } label: {
                ZStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [Color.claroViolet, Color(hex: "#6D28D9")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(isPurchasing || store.isLoading ? 0.6 : 1.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow()
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring || store.isLoading)

            // ── Restore Purchase ────────────────────────────────────────
            // Required by App Store guideline 3.1.1
            Button {
                Task { await handleRestore() }
            } label: {
                if isRestoring {
                    ProgressView().scaleEffect(0.75).tint(Color.claroTextMuted)
                } else {
                    Text("Restore Purchase")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                        .underline()
                }
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring)
        }
    }

    private var ctaLabel: LocalizedStringKey {
        switch selectedPlan {
        case .annual:   return "Start 3-Day Free Trial"
        case .monthly:  return "Get Pro Monthly"
        case .lifetime: return "Get Lifetime Access"
        }
    }

    // MARK: - Legal  (required by App Store guidelines)

    private var legalSection: some View {
        VStack(spacing: 10) {

            // Trial renewal disclosure — required when a free trial is offered
            if selectedPlan == .annual {
                Text("""
                    After your 3-day free trial, you will be charged \
                    \(store.annualProduct?.displayPrice ?? "₪79.90") per year. \
                    Cancel any time before the trial ends in \
                    Settings → Apple ID → Subscriptions.
                    """)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.claroTextMuted)
                    .multilineTextAlignment(.center)
            }

            // Tappable ToS & Privacy links — required by Apple
            HStack(spacing: 6) {
                Button { showTerms   = true } label: {
                    Text("Terms of Service")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.claroTextMuted)
                        .underline()
                }
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.claroTextMuted)
                Button { showPrivacy = true } label: {
                    Text("Privacy Policy")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.claroTextMuted)
                        .underline()
                }
            }
            .buttonStyle(.plain)

            // Subscription boilerplate (required)
            Text("""
                Payment charged to your Apple ID. Subscriptions renew automatically \
                unless cancelled at least 24 hours before the end of the current period. \
                Manage subscriptions in Settings → Apple ID → Subscriptions.
                """)
                .font(.system(size: 9))
                .foregroundStyle(Color.claroTextMuted.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    @MainActor
    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let productID: String
        switch selectedPlan {
        case .annual:   productID = StoreKitService.annualID
        case .monthly:  productID = StoreKitService.monthlyID
        case .lifetime: productID = StoreKitService.lifetimeID
        }

        guard let product = store.product(for: productID) else {
            alertTitle   = "Not Available"
            alertMessage = "This product isn't available right now. Please try again later."
            showAlert    = true
            return
        }

        do {
            let purchased = try await store.purchase(product)
            if purchased { dismiss() }
        } catch {
            alertTitle   = "Purchase Failed"
            alertMessage = "Something went wrong. Please try again."
            showAlert    = true
        }
    }

    @MainActor
    private func handleRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await store.restore()
            if store.isPro {
                dismiss()
            } else {
                alertTitle   = "No Purchases Found"
                alertMessage = "No previous purchases were found for your Apple ID."
                showAlert    = true
            }
        } catch {
            alertTitle   = "Restore Failed"
            alertMessage = "Something went wrong. Please try again."
            showAlert    = true
        }
    }
}

// MARK: - Impact Pill

private struct ImpactPill: View {
    let emoji: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 58, height: 58)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(color.opacity(0.2), lineWidth: 1)
                    )

                Text(value)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.claroDanger)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -6)
            }
            Text(label)
                .font(.claroCaption())
                .foregroundStyle(Color.claroTextMuted)
        }
    }
}

#Preview { PaywallView() }
#Preview("With scan results") {
    PaywallView(photoDuplicates: 347, contactDups: 23, reclaimableGB: 4.7)
}
