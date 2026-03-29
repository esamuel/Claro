import SwiftUI

struct SupportedLanguage: Identifiable {
    let id: String        // BCP-47 language code
    let name: String      // Name in English
    let localName: String // Name in that language
    let flag: String
}

let supportedLanguages: [SupportedLanguage] = [
    SupportedLanguage(id: "en", name: "English",  localName: "English", flag: "🇺🇸"),
    SupportedLanguage(id: "he", name: "Hebrew",   localName: "עברית",   flag: "🇮🇱"),
]

struct LanguagePickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: ClaroSpacing.lg) {

                    // Info card
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.claroCyan)
                        Text("The app will use your selected language, independent of your device language.")
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroTextSecondary)
                    }
                    .padding(ClaroSpacing.md)
                    .background(Color.claroCyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ClaroRadius.sm)
                            .strokeBorder(Color.claroCyan.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Language options
                    VStack(spacing: ClaroSpacing.sm) {
                        ForEach(supportedLanguages) { lang in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    settings.setLanguage(lang.id)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Text(lang.flag)
                                        .font(.system(size: 30))
                                        .frame(width: 48, height: 48)
                                        .background(Color.claroCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lang.localName)
                                            .font(.claroHeadline())
                                            .foregroundStyle(Color.claroTextPrimary)
                                        Text(lang.name)
                                            .font(.claroCaption())
                                            .foregroundStyle(Color.claroTextMuted)
                                    }

                                    Spacer()

                                    if settings.languageCode == lang.id {
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
                                .padding(.vertical, 14)
                                .background(
                                    settings.languageCode == lang.id
                                        ? Color.claroViolet.opacity(0.1)
                                        : Color.claroCard
                                )
                                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ClaroRadius.md)
                                        .strokeBorder(
                                            settings.languageCode == lang.id
                                                ? Color.claroViolet.opacity(0.45)
                                                : Color.claroCardBorder,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, ClaroSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Language")
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
