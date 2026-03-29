import SwiftUI

struct ClaroCard<Content: View>: View {
    var padding: CGFloat = ClaroSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(Color.claroCardBorder, lineWidth: 1)
            )
            .claroCardShadow()
    }
}

struct ClaroToolRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
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

                if let badge {
                    Text(badge)
                        .font(.claroLabel())
                        .foregroundStyle(Color.claroVioletLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.claroViolet.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .buttonStyle(.plain)
    }
}

struct ClaroSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String?    = nil
    var isLoading: Bool   = false
    var isDestructive: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                Text(LocalizedStringKey(title))
                    .font(.claroHeadline())
                    .foregroundStyle(isDestructive ? Color.claroDanger : Color.claroTextPrimary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(Color.claroTextSecondary)
                        .scaleEffect(0.8)
                } else if let value {
                    // Treat value as a LocalizedStringKey so "Light"→"בהיר" etc. auto-translate
                    Text(LocalizedStringKey(value))
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.claroTextMuted.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Note

/// A small ⓘ button that expands a one-line hint inline when tapped.
struct InfoNote: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(expanded ? Color.claroViolet : Color.claroTextMuted)
            }
            .buttonStyle(.plain)

            if expanded {
                Text(text)
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Section Label

struct ClaroSectionLabel: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .font(.claroLabel())
            .foregroundStyle(Color.claroTextMuted)
            .textCase(.uppercase)
            .kerning(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
