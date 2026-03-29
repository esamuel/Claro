import SwiftUI

struct AppearancePickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                VStack(spacing: ClaroSpacing.sm) {
                    ForEach(AppSettings.ColorSchemePreference.allCases) { pref in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.setColorScheme(pref)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(pref.iconColor.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: pref.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(pref.iconColor)
                                }

                                Text(pref.label)
                                    .font(.claroHeadline())
                                    .foregroundStyle(Color.claroTextPrimary)

                                Spacer()

                                if settings.colorSchemePreference == pref {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.claroViolet)
                                } else {
                                    Circle()
                                        .strokeBorder(Color.claroTextMuted.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .background(
                                settings.colorSchemePreference == pref
                                    ? Color.claroViolet.opacity(0.1)
                                    : Color.claroCard
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ClaroRadius.md)
                                    .strokeBorder(
                                        settings.colorSchemePreference == pref
                                            ? Color.claroViolet.opacity(0.45)
                                            : Color.claroCardBorder,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, ClaroSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Appearance")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.claroHeadline())
                        .foregroundStyle(Color.claroViolet)
                }
            }
        }
    }
}
