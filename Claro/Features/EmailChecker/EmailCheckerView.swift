import SwiftUI

private let checkerPurple = Color(hex: "#8B5CF6")

struct EmailCheckerView: View {
    @State private var service = EmailCheckerService()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ClaroSpacing.lg) {

                        headerCard.padding(.horizontal)
                        inputSection.padding(.horizontal)
                        resultSection
                        Spacer(minLength: ClaroSpacing.xxl)
                    }
                    .padding(.top, ClaroSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Email Checker")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
            .onTapGesture { fieldFocused = false }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A0A3E"), Color(hex: "#0A1628")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(checkerPurple.opacity(0.3))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 80, y: -30)

            VStack(spacing: ClaroSpacing.sm) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(checkerPurple)
                Text("Data Breach Scanner")
                    .font(.claroTitle2())
                    .foregroundStyle(.white)
                Text("Check if your email appeared in a known data leak")
                    .font(.claroCaption())
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(checkerPurple.opacity(0.3), lineWidth: 1)
        )
        .frame(minHeight: 160)
        .claroCardShadow()
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(checkerPurple)
                    .font(.system(size: 15))

                TextField("Enter your email address", text: $service.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextPrimary)
                    .submitLabel(.search)
                    .onSubmit { Task { await service.check() } }

                if !service.email.isEmpty {
                    Button { service.email = ""; service.reset() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.claroTextMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(
                        fieldFocused ? checkerPurple.opacity(0.5) : Color.claroCardBorder,
                        lineWidth: fieldFocused ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: fieldFocused)

            Button {
                fieldFocused = false
                Task { await service.check() }
            } label: {
                HStack(spacing: 8) {
                    if case .checking = service.state {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Checking…")
                    } else {
                        Image(systemName: "magnifyingglass.circle.fill")
                        Text("Check for Breaches")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [checkerPurple, Color(hex: "#6D28D9")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow()
            }
            .buttonStyle(.plain)
            .disabled(!service.isValidEmail || {
                if case .checking = service.state { return true }
                return false
            }())
            .opacity(service.isValidEmail ? 1 : 0.5)
            .animation(.easeInOut(duration: 0.2), value: service.isValidEmail)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultSection: some View {
        switch service.state {
        case .idle, .checking:
            EmptyView()

        case .result(let rep):
            ResultCard(rep: rep, email: service.email)
                .padding(.horizontal)

        case .error(let msg):
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.claroWarning)
                Text(msg)
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextSecondary)
                Spacer()
            }
            .padding(16)
            .background(Color.claroWarning.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(Color.claroWarning.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)

        case .cooldown(let until):
            CooldownCard(until: until)
                .padding(.horizontal)
        }
    }
}

// MARK: - Result Card

private struct ResultCard: View {
    let rep:   EmailReputation
    let email: String

    private var accent: Color {
        switch rep.riskLevel {
        case .high:   return .claroDanger
        case .medium: return .claroWarning
        case .low:    return .claroSuccess
        }
    }

    private var icon: String {
        switch rep.riskLevel {
        case .high:   return "exclamationmark.shield.fill"
        case .medium: return "shield.lefthalf.filled"
        case .low:    return "checkmark.shield.fill"
        }
    }

    private var headline: String {
        switch rep.riskLevel {
        case .high:   return "High Risk — Action Needed"
        case .medium: return "Moderate Risk"
        case .low:    return "No Breaches Found"
        }
    }

    private var subline: String {
        switch rep.riskLevel {
        case .high:   return "Credentials from this email were leaked. Change your passwords now."
        case .medium: return "This email has appeared in data breaches. Review your passwords."
        case .low:    return "This email didn't appear in any known data leak."
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Status banner ──────────────────────────────────────────
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.claroHeadline())
                        .foregroundStyle(accent)
                    Text(subline)
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextSecondary)
                        .lineSpacing(2)
                }
            }
            .padding(16)

            Divider().opacity(0.1)

            // ── Detail rows ────────────────────────────────────────────
            VStack(spacing: 0) {
                DetailRow(
                    icon:   "key.fill",
                    label:  "Credentials leaked",
                    value:  rep.details.credentialsLeaked ? "Yes" : "No",
                    danger: rep.details.credentialsLeaked
                )
                DetailRow(
                    icon:   "clock.arrow.circlepath",
                    label:  "Recent leak",
                    value:  rep.details.credentialsLeakedRecent ? "Yes" : "No",
                    danger: rep.details.credentialsLeakedRecent
                )
                DetailRow(
                    icon:   "externaldrive.badge.exclamationmark",
                    label:  "Data breach",
                    value:  rep.details.dataBreach ? "Yes" : "No",
                    danger: rep.details.dataBreach
                )
                DetailRow(
                    icon:   "hand.raised.fill",
                    label:  "Blacklisted",
                    value:  rep.details.blacklisted ? "Yes" : "No",
                    danger: rep.details.blacklisted
                )
                DetailRow(
                    icon:   "person.badge.shield.checkmark",
                    label:  "Reputation",
                    value:  rep.reputation.capitalized,
                    danger: rep.reputation == "low" || rep.reputation == "none"
                )
            }

            Divider().opacity(0.1)

            // ── Full report button ─────────────────────────────────────
            Button {
                let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
                if let url = URL(string: "https://haveibeenpwned.com/account/\(encoded)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                    Text("View Full Report on HaveIBeenPwned")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(checkerPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon:   String
    let label:  String
    let value:  String
    let danger: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(danger ? Color.claroDanger : Color.claroTextMuted)
                .frame(width: 20)
            Text(label)
                .font(.claroCaption())
                .foregroundStyle(Color.claroTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(danger ? Color.claroDanger : Color.claroSuccess)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Cooldown Card

private struct CooldownCard: View {
    let until: Date
    @State private var remaining: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(Color.claroWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text("Too many requests")
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                Text(remaining > 0
                     ? "Please wait \(remaining)s before trying again."
                     : "You can try again now.")
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.claroWarning.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroWarning.opacity(0.3), lineWidth: 1)
        )
        .onAppear { remaining = max(0, Int(until.timeIntervalSinceNow)) }
        .onReceive(timer) { _ in
            remaining = max(0, Int(until.timeIntervalSinceNow))
        }
    }
}

#Preview {
    EmailCheckerView()
        .background(Color.claroBg)
}
