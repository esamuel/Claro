import SwiftUI

enum LegalDocumentType { case terms, privacy }

/// Bilingual (English / Hebrew) in-app legal document viewer.
/// Language follows the app's current language setting.
struct LegalView: View {
    let type: LegalDocumentType

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss)        private var dismiss

    private var isHebrew: Bool { settings.languageCode == "he" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: isHebrew ? .trailing : .leading, spacing: 0) {
                        content
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .environment(\.layoutDirection, isHebrew ? .rightToLeft : .leftToRight)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle)
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isHebrew ? "סיום" : "Done") { dismiss() }
                        .font(.claroHeadline())
                        .foregroundStyle(Color.claroViolet)
                }
            }
        }
    }

    private var navigationTitle: String {
        switch type {
        case .terms:   return isHebrew ? "תנאי שימוש"      : "Terms of Service"
        case .privacy: return isHebrew ? "מדיניות פרטיות"  : "Privacy Policy"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch type {
        case .terms:   isHebrew ? AnyView(termsHebrew)   : AnyView(termsEnglish)
        case .privacy: isHebrew ? AnyView(privacyHebrew) : AnyView(privacyEnglish)
        }
    }

    // MARK: - Terms of Service (English)

    private var termsEnglish: some View {
        LegalDocument(sections: [
            .init(title: "Terms of Service",
                  body: "Last updated: March 2026\n\nWelcome to Claro. By downloading or using Claro you agree to these terms.",
                  isHeader: true),
            .init(title: "1. Description of Service",
                  body: "Claro is a storage-management app that helps you identify and remove duplicate photos and contacts from your iPhone. All processing occurs locally on your device."),
            .init(title: "2. In-App Purchases",
                  body: "Claro offers optional Pro subscriptions (monthly, annual, lifetime). Payments are processed exclusively through Apple's App Store. Prices are shown in your local currency and may vary by region.\n\nSubscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel subscriptions in Settings → Apple ID → Subscriptions."),
            .init(title: "3. Free Trial",
                  body: "The annual plan includes a 3-day free trial. If you do not cancel before the trial ends, the annual subscription price will be charged to your Apple ID."),
            .init(title: "4. Privacy",
                  body: "We do not upload your photos, contacts, or any personal files to external servers. See our Privacy Policy for full details."),
            .init(title: "5. Limitation of Liability",
                  body: "Claro is provided \"as is\" without warranty of any kind. We are not responsible for any data loss resulting from the use of the app. Always back up your data before performing a clean-up."),
            .init(title: "6. Changes to Terms",
                  body: "We may update these terms from time to time. Continued use of the app after changes constitutes acceptance of the new terms."),
            .init(title: "7. Contact",
                  body: "Questions about these terms? Contact us at:\nsameskapple@gmail.com"),
        ])
    }

    // MARK: - Terms of Service (Hebrew)

    private var termsHebrew: some View {
        LegalDocument(sections: [
            .init(title: "תנאי שימוש",
                  body: "עדכון אחרון: מרץ 2026\n\nברוכים הבאים ל-Claro. בהורדה או שימוש ב-Claro, אתה מסכים לתנאים אלה.",
                  isHeader: true),
            .init(title: "1. תיאור השירות",
                  body: "Claro היא אפליקציה לניהול אחסון שעוזרת לך לזהות ולהסיר תמונות ואנשי קשר כפולים מה-iPhone שלך. כל העיבוד מתבצע באופן מקומי במכשיר שלך."),
            .init(title: "2. רכישות בתוך האפליקציה",
                  body: "Claro מציעה מנויי Pro אופציונליים (חודשי, שנתי, לכל החיים). התשלומים מעובדים אך ורק דרך App Store של Apple. המחירים מוצגים במטבע המקומי שלך.\n\nמנויים מתחדשים אוטומטית אלא אם כן בוטלו לפחות 24 שעות לפני סוף התקופה הנוכחית. תוכל לנהל מנויים דרך הגדרות ← Apple ID ← מנויים."),
            .init(title: "3. תקופת ניסיון",
                  body: "התוכנית השנתית כוללת ניסיון חינם של 3 ימים. אם לא תבטל לפני סוף הניסיון, מחיר המנוי השנתי ייגבה מ-Apple ID שלך."),
            .init(title: "4. פרטיות",
                  body: "אנחנו לא מעלים את התמונות, אנשי הקשר או קבצים אישיים שלך לשרתים חיצוניים. ראה את מדיניות הפרטיות שלנו לפרטים נוספים."),
            .init(title: "5. הגבלת אחריות",
                  body: "Claro מסופקת \"כמות שהיא\" ללא אחריות מכל סוג שהוא. אנחנו לא אחראים לאובדן נתונים כלשהו הנובע משימוש באפליקציה. תמיד גבה את הנתונים שלך לפני ביצוע ניקוי."),
            .init(title: "6. שינויים בתנאים",
                  body: "ייתכן שנעדכן תנאים אלה מעת לעת. המשך השימוש באפליקציה לאחר השינויים מהווה קבלה של התנאים החדשים."),
            .init(title: "7. צרו קשר",
                  body: "שאלות לגבי תנאים אלה? צרו איתנו קשר:\nsameskapple@gmail.com"),
        ], rtl: true)
    }

    // MARK: - Privacy Policy (English)

    private var privacyEnglish: some View {
        LegalDocument(sections: [
            .init(title: "Privacy Policy",
                  body: "Last updated: March 2026\n\nClaro takes your privacy seriously. This policy explains what data we access and how we use it.",
                  isHeader: true),
            .init(title: "1. Data We Access On-Device",
                  body: "• Photos — to detect and group duplicates. No photos leave your device.\n• Contacts — to detect duplicates. No contacts are uploaded.\n• Device Storage — to display storage usage statistics.\n• Notifications — to send weekly scan reminders (only with your permission)."),
            .init(title: "2. Data We Do NOT Collect",
                  body: "• We do not upload your photos, contacts, or any personal files to our servers.\n• We do not have access to your iCloud data.\n• We do not sell or share your data with third parties."),
            .init(title: "3. In-App Purchases",
                  body: "Purchase history and payment information are managed entirely by Apple. We do not store or have access to your payment details."),
            .init(title: "4. Analytics",
                  body: "We may collect anonymous, non-identifiable crash reports to improve app stability. No personal information is included in these reports."),
            .init(title: "5. Data Retention",
                  body: "All data processing is performed locally on your device. Claro does not operate servers that store your personal data."),
            .init(title: "6. Children",
                  body: "Claro is not directed at children under 13. We do not knowingly collect data from children."),
            .init(title: "7. Contact",
                  body: "Privacy questions?\nsameskapple@gmail.com"),
        ])
    }

    // MARK: - Privacy Policy (Hebrew)

    private var privacyHebrew: some View {
        LegalDocument(sections: [
            .init(title: "מדיניות פרטיות",
                  body: "עדכון אחרון: מרץ 2026\n\nClaro לוקחת את הפרטיות שלך ברצינות. מדיניות זו מסבירה לאילו נתונים אנו ניגשים וכיצד אנו משתמשים בהם.",
                  isHeader: true),
            .init(title: "1. נתונים שאנו ניגשים אליהם במכשיר",
                  body: "• תמונות — לזיהוי וקיבוץ כפילויות. אף תמונה לא יוצאת מהמכשיר שלך.\n• אנשי קשר — לזיהוי כפילויות. אין העלאה של אנשי קשר.\n• אחסון המכשיר — להצגת סטטיסטיקות שימוש.\n• התראות — לשליחת תזכורות סריקה שבועיות (רק עם הסכמתך)."),
            .init(title: "2. נתונים שאנו לא אוספים",
                  body: "• אנחנו לא מעלים את התמונות, אנשי הקשר או קבצים אישיים שלך לשרתים שלנו.\n• אין לנו גישה לנתוני iCloud שלך.\n• אנחנו לא מוכרים או משתפים את הנתונים שלך עם צדדים שלישיים."),
            .init(title: "3. רכישות בתוך האפליקציה",
                  body: "היסטוריית הרכישות ופרטי התשלום מנוהלים לחלוטין על ידי Apple. אין לנו גישה לפרטי התשלום שלך."),
            .init(title: "4. אנליטיקה",
                  body: "ייתכן שנאסוף דוחות קריסה אנונימיים ולא מזוהים לשיפור יציבות האפליקציה. אין מידע אישי כלול בדוחות אלה."),
            .init(title: "5. שמירת נתונים",
                  body: "כל עיבוד הנתונים מתבצע באופן מקומי במכשיר שלך. Claro לא מפעילה שרתים ששומרים את הנתונים האישיים שלך."),
            .init(title: "6. ילדים",
                  body: "Claro אינה מיועדת לילדים מתחת לגיל 13. אנחנו לא אוספים ביודעין נתונים מילדים."),
            .init(title: "7. צרו קשר",
                  body: "שאלות בנושא פרטיות?\nsameskapple@gmail.com"),
        ], rtl: true)
    }
}

// MARK: - Document Renderer

private struct LegalSection: Identifiable {
    let id    = UUID()
    let title: String
    let body:  String
    var isHeader: Bool = false
}

private struct LegalDocument: View {
    let sections: [LegalSection]
    var rtl: Bool = false

    var body: some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 24) {
            ForEach(sections) { section in
                VStack(alignment: rtl ? .trailing : .leading, spacing: 8) {
                    Text(section.title)
                        .font(section.isHeader
                              ? .system(size: 22, weight: .black)
                              : .system(size: 15, weight: .bold))
                        .foregroundStyle(section.isHeader ? Color.claroViolet : Color.claroTextPrimary)
                        .multilineTextAlignment(rtl ? .trailing : .leading)

                    Text(section.body)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claroTextSecondary)
                        .lineSpacing(5)
                        .multilineTextAlignment(rtl ? .trailing : .leading)
                }
            }
        }
    }
}

#Preview("English") { LegalView(type: .terms)   .environment(AppSettings()) }
#Preview("Hebrew")  { LegalView(type: .privacy) .environment(AppSettings()) }
