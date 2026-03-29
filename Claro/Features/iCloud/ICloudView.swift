import SwiftUI
import Photos

struct ICloudView: View {
    @Environment(PermissionsService.self) private var permissions
    @Environment(ICloudService.self)      private var service

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                switch permissions.photoStatus {
                case .notDetermined:
                    PermissionRequestView(
                        icon: "icloud.fill",
                        iconColor: .claroCyan,
                        title: "iCloud Manager",
                        description: "Grant photo access so Claro can find large videos and photos eating your storage.",
                        buttonTitle: "Grant Access"
                    ) {
                        Task { await permissions.requestPhotoAccess() }
                    }

                case .denied, .restricted:
                    PermissionDeniedView(
                        icon: "icloud.fill",
                        iconColor: .claroCyan,
                        title: "Access Required",
                        description: "Photo access was denied. Enable it in Settings to use iCloud Manager."
                    ) {
                        permissions.openSettings()
                    }

                case .authorized, .limited:
                    ICloudContentView()

                @unknown default:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("iCloud Manager")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
            .onAppear { permissions.refresh() }
        }
    }
}

// MARK: - Content

struct ICloudContentView: View {
    @Environment(ICloudService.self) private var service
    @State private var showReview = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ClaroSpacing.lg) {

                summaryCard.padding(.horizontal)

                if service.scanComplete {
                    VStack(spacing: ClaroSpacing.sm) {
                        // Section header + info note
                        HStack(alignment: .center) {
                            ClaroSectionLabel(title: "Your Largest Files")
                            InfoNote(text: "Sorted by size — not duplicates. Always review before deleting.")
                        }
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "video.fill",
                            iconColor: .claroCyan,
                            title: "Videos",
                            subtitle: service.videoCount > 0
                                ? "\(service.videoCount) videos · sorted by size"
                                : "No videos found"
                        ) { if service.videoCount > 0 { showReview = true } }
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "photo.fill",
                            iconColor: .claroVioletLight,
                            title: "Heavy Photos",
                            subtitle: service.photoCount > 0
                                ? "\(service.photoCount) photos over 8 MB (ProRAW, HDR…)"
                                : "No heavy photos found"
                        ) { if service.photoCount > 0 { showReview = true } }
                        .padding(.horizontal)
                    }

                    // iCloud settings shortcut
                    VStack(spacing: ClaroSpacing.sm) {
                        ClaroSectionLabel(title: "Manage").padding(.horizontal)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.claroCyan)
                                    .frame(width: 32, height: 32)
                                    .background(Color.claroCyan.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iCloud Storage Settings")
                                        .font(.claroHeadline())
                                        .foregroundStyle(Color.claroTextPrimary)
                                    Text("Manage backups, optimize storage")
                                        .font(.claroCaption())
                                        .foregroundStyle(Color.claroTextMuted)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 14))
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
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: ClaroSpacing.xxl)
            }
            .padding(.top, ClaroSpacing.md)
        }
        .sheet(isPresented: $showReview) {
            LargeMediaReviewView(service: service)
        }
        .task { await service.scan() }
        .onAppear {
            if service.pendingReview {
                service.pendingReview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showReview = true
                }
            }
        }
    }

    // MARK: Summary card

    private var summaryCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#001F2E"), Color(hex: "#0A1628")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.claroCyan.opacity(0.25))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 80, y: -30)

            VStack(spacing: ClaroSpacing.sm) {
                if service.isScanning {
                    VStack(spacing: ClaroSpacing.md) {
                        ProgressView()
                            .tint(Color.claroCyan)
                            .scaleEffect(1.4)
                        Text("Scanning your media…")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("Finding large files")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else if service.scanComplete && service.items.isEmpty {
                    VStack(spacing: ClaroSpacing.sm) {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.claroCyan)
                        Text("All Clear!")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("No large files taking up space")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.claroCyan)

                    Text("\(service.totalFormatted) in large files")
                        .font(.claroTitle2())
                        .foregroundStyle(.white)

                    Text("\(service.items.count) files · review before deleting")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.55))

                    Button { showReview = true } label: {
                        Text("Review Files")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.claroCyan, Color(hex: "#0891B2")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                            .claroGlowShadow(color: .claroCyan)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .disabled(service.items.isEmpty)
                }
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroCyan.opacity(0.25), lineWidth: 1)
        )
        .frame(minHeight: 180)
        .claroCardShadow()
    }
}

#Preview { ICloudView() }
