import SwiftUI

struct HomeView: View {
    @Environment(PermissionsService.self)      private var permissions
    @Environment(StoreKitService.self)         private var store
    @Environment(DuplicatePhotoService.self)   private var photoService
    @Environment(ICloudService.self)           private var iCloudService
    @Environment(ContactService.self)          private var contactService
    @Environment(VaultService.self)            private var vaultService

    @Binding var selectedTab: ClaroTab

    @State private var showPaywall      = false
    @State private var showSettings     = false
    @State private var showSmartClean   = false
    @State private var showVault        = false
    @State private var showEmailChecker = false
    @State private var storage        = StorageService.load()
    @State private var isScanning     = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ClaroSpacing.md) {
                        StorageCard(storage: storage)
                            .padding(.horizontal)

                        SmartCleanButton(isScanning: isScanning) {
                            showSmartClean = true
                        }
                        .padding(.horizontal)

                        QuickStatsRow(photoService: photoService, contactService: contactService)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
                            ClaroSectionLabel(title: "Clean")
                                .padding(.horizontal)

                            ClaroToolRow(
                                icon: "photo.stack.fill",
                                iconColor: .claroVioletLight,
                                title: "Photo Cleaner",
                                subtitle: photoService.isScanning
                                    ? "Scanning…"
                                    : "\(photoService.totalDuplicates) duplicates found",
                                badge: photoService.totalDuplicates > 0 ? "New" : nil
                            ) { selectedTab = .photos }
                            .padding(.horizontal)

                            ClaroToolRow(
                                icon: "icloud.fill",
                                iconColor: .claroCyan,
                                title: "iCloud Manager",
                                subtitle: iCloudService.isScanning
                                    ? "Scanning…"
                                    : iCloudService.items.isEmpty && iCloudService.scanComplete
                                        ? "No large files found"
                                        : "\(iCloudService.totalFormatted) in large files"
                            ) { selectedTab = .iCloud }
                            .padding(.horizontal)

                            ClaroToolRow(
                                icon: "person.2.fill",
                                iconColor: .claroGold,
                                title: "Contact Cleaner",
                                subtitle: contactService.isScanning
                                    ? "Scanning…"
                                    : contactService.groupCount > 0
                                        ? "\(contactService.groupCount) duplicate groups found"
                                        : contactService.scanComplete
                                            ? "No duplicates found"
                                            : "Merge duplicate contacts",
                                badge: contactService.groupCount > 0 ? "New" : nil
                            ) { selectedTab = .contacts }
                            .padding(.horizontal)
                        }

                        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
                            ClaroSectionLabel(title: "Tools")
                                .padding(.horizontal)

                            ClaroToolRow(
                                icon: "lock.shield.fill",
                                iconColor: .claroSuccess,
                                title: "Private Vault",
                                subtitle: vaultService.items.isEmpty
                                    ? "Encrypted local storage"
                                    : "\(vaultService.items.count) encrypted photos"
                            ) { showVault = true }
                            .padding(.horizontal)

                            ClaroToolRow(
                                icon: "envelope.badge.shield.half.filled.fill",
                                iconColor: Color(hex: "#8B5CF6"),
                                title: "Email Checker",
                                subtitle: "Verify if your email is leaked"
                            ) { showEmailChecker = true }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: ClaroSpacing.xxl)
                    }
                    .padding(.top, ClaroSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Crown → Paywall / upgrade
                    Button { showPaywall = true } label: {
                        ProBadge()
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .principal) {
                    Text("Claro")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Gear → Settings
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.claroTextSecondary)
                            .padding(8)
                            .background(Color.claroCard)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $showVault) {
            VaultView()
                .environment(vaultService)
        }
        .sheet(isPresented: $showEmailChecker) {
            EmailCheckerView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(permissions)
                .environment(store)
        }
        .fullScreenCover(isPresented: $showSmartClean) {
            SmartCleanView(
                onReviewPhotos: {
                    showSmartClean             = false
                    selectedTab                = .photos
                    photoService.pendingReview = true
                },
                onReviewICloud: {
                    showSmartClean              = false
                    selectedTab                 = .iCloud
                    iCloudService.pendingReview = true
                },
                onReviewContacts: {
                    showSmartClean               = false
                    selectedTab                  = .contacts
                    contactService.pendingReview = true
                }
            )
            .environment(permissions)
            .environment(store)
        }
        .onAppear { storage = StorageService.load() }
    }
}

// MARK: - Storage Card

struct StorageCard: View {
    let storage: StorageInfo

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1A0A3E"),
                    Color(hex: "#0F1B3D"),
                    Color(hex: "#0A1628")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glow orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.claroViolet.opacity(0.35))
                    .frame(width: 140, height: 140)
                    .blur(radius: 50)
                    .offset(x: geo.size.width - 60, y: -50)

                Circle()
                    .fill(Color.claroCyan.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 40)
                    .offset(x: 20, y: geo.size.height - 30)
            }

            // Text inside this card is always on a dark background —
            // use fixed white-based colours regardless of light/dark mode.
            VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
                Text("Storage Used")
                    .font(.claroCaption())
                    .foregroundStyle(Color.white.opacity(0.55))
                    .kerning(0.5)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(storage.usedFormatted)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("GB")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("of \(Int(storage.totalGB)) GB")
                        .font(.claroBody())
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.claroViolet, Color.claroCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * storage.usedPercent, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(Int(storage.usedPercent * 100))% used")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroVioletLight)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(storage.freeFormatted) GB free")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroViolet.opacity(0.25), lineWidth: 1)
        )
        .frame(height: 160)
        .claroCardShadow()
    }
}

// MARK: - Smart Clean Button

struct SmartCleanButton: View {
    var isScanning: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .symbolEffect(.pulse, value: isScanning)

                Text("Smart Clean with AI")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.claroViolet, Color(hex: "#6D28D9")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .claroGlowShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Stats

struct QuickStatsRow: View {
    let photoService:   DuplicatePhotoService
    let contactService: ContactService

    private var reclaimableLabel: String {
        let gb = photoService.totalReclaimableGB
        return gb >= 0.1 ? String(format: "%.1f GB", gb) : photoService.reclaimableFormatted
    }

    var body: some View {
        HStack(spacing: 10) {
            StatCard(
                icon: "doc.on.doc.fill",
                iconColor: .claroDanger,
                value: photoService.isScanning ? "—" : "\(photoService.totalDuplicates)",
                label: "Duplicates"
            )
            StatCard(
                icon: "internaldrive.fill",
                iconColor: .claroCyan,
                value: photoService.isScanning ? "—" : reclaimableLabel,
                label: "Reclaimable"
            )
            StatCard(
                icon: "person.2.fill",
                iconColor: .claroGold,
                value: contactService.isScanning ? "—" : "\(contactService.totalDuplicates)",
                label: "Contacts"
            )
        }
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.claroTextPrimary)

            Text(label)
                .font(.claroLabel())
                .foregroundStyle(Color.claroTextMuted)
        }
        .padding(ClaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
    }
}


#Preview {
    HomeView(selectedTab: .constant(.home))
}
