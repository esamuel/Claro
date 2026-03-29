import SwiftUI

struct MoreView: View {
    @Environment(StoreKitService.self) private var store

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ClaroSpacing.lg) {

                        // Pro tools section
                        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
                            ClaroSectionLabel(title: "Pro Tools")
                                .padding(.horizontal)

                            NavigationLink(destination: OptimizerView()) {
                                MoreToolRow(
                                    icon: "bolt.fill",
                                    iconColor: .claroGold,
                                    title: "Optimizer",
                                    subtitle: "Boost battery & performance",
                                    isPro: true
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)

                            NavigationLink(destination: CompressionView()) {
                                MoreToolRow(
                                    icon: "arrow.down.circle.fill",
                                    iconColor: .claroCyan,
                                    title: "Compression",
                                    subtitle: "Shrink photos & videos",
                                    isPro: true
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)

                            NavigationLink(destination: EmailCleanerView()) {
                                MoreToolRow(
                                    icon: "tray.fill",
                                    iconColor: .claroSuccess,
                                    title: "Email Cleaner",
                                    subtitle: "Clean your inbox",
                                    isPro: true
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: ClaroSpacing.xxl)
                    }
                    .padding(.top, ClaroSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("More")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
        }
    }
}

// MARK: - MoreToolRow

private struct MoreToolRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isPro: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                Text(LocalizedStringKey(subtitle))
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextMuted)
            }

            Spacer()

            if isPro {
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("PRO")
                        .font(.claroLabel())
                        .kerning(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.claroTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    MoreView()
}
