import SwiftUI

enum ClaroTab: String, CaseIterable {
    case home     = "Home"
    case photos   = "Photos"
    case iCloud   = "iCloud"
    case contacts = "Contacts"
    case settings = "More"

    var icon: String {
        switch self {
        case .home:     return "bolt.fill"
        case .photos:   return "photo.stack.fill"
        case .iCloud:   return "icloud.fill"
        case .contacts: return "person.2.fill"
        case .settings: return "ellipsis"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: ClaroTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tag(ClaroTab.home)
                .tabItem {
                    Label(LocalizedStringKey(ClaroTab.home.rawValue), systemImage: ClaroTab.home.icon)
                }

            PhotosView()
                .tag(ClaroTab.photos)
                .tabItem {
                    Label(LocalizedStringKey(ClaroTab.photos.rawValue), systemImage: ClaroTab.photos.icon)
                }

            ICloudView()
                .tag(ClaroTab.iCloud)
                .tabItem {
                    Label(LocalizedStringKey(ClaroTab.iCloud.rawValue), systemImage: ClaroTab.iCloud.icon)
                }

            ContactsView()
                .tag(ClaroTab.contacts)
                .tabItem {
                    Label(LocalizedStringKey(ClaroTab.contacts.rawValue), systemImage: ClaroTab.contacts.icon)
                }

            MoreView()
                .tag(ClaroTab.settings)
                .tabItem {
                    Label(LocalizedStringKey(ClaroTab.settings.rawValue), systemImage: ClaroTab.settings.icon)
                }
        }
        .tint(Color.claroViolet)
        .onAppear { styleTabBar() }
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.claroBg).withAlphaComponent(0.97)

        // Border line
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.07)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MainTabView()
}
