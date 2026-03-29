import SwiftUI
import Photos

struct PhotosView: View {
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBg.ignoresSafeArea()

                switch permissions.photoStatus {
                case .notDetermined:
                    PermissionRequestView(
                        icon: "photo.stack.fill",
                        iconColor: .claroVioletLight,
                        title: "Photo Cleaner",
                        description: "Grant Claro access to your photo library to find and remove duplicates, freeing up valuable storage.",
                        buttonTitle: "Grant Access"
                    ) {
                        Task { await permissions.requestPhotoAccess() }
                    }

                case .denied, .restricted:
                    PermissionDeniedView(
                        icon: "photo.stack.fill",
                        iconColor: .claroVioletLight,
                        title: "Access Required",
                        description: "Photo access was denied. Please enable it in Settings to use the Photo Cleaner."
                    ) {
                        permissions.openSettings()
                    }

                case .authorized, .limited:
                    PhotosContentView()

                @unknown default:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Photo Cleaner")
                        .font(.claroTitle2())
                        .foregroundStyle(Color.claroTextPrimary)
                }
            }
            .onAppear { permissions.refresh() }
        }
    }
}

// MARK: - Content (permission granted)

struct PhotosContentView: View {
    @Environment(DuplicatePhotoService.self) private var service
    @State private var showReview  = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ClaroSpacing.lg) {

                // ── Summary card ──────────────────────────────────────────
                summaryCard
                    .padding(.horizontal)

                // ── Category breakdown ────────────────────────────────────
                if service.scanComplete {
                    VStack(spacing: ClaroSpacing.sm) {
                        ClaroSectionLabel(title: "Found").padding(.horizontal)

                        ClaroToolRow(
                            icon: "photo.fill.on.rectangle.fill",
                            iconColor: .claroDanger,
                            title: "Exact Duplicates",
                            subtitle: "\(service.totalDuplicates) photos · \(service.reclaimableFormatted)"
                        ) { if service.totalDuplicates > 0 { showReview = true } }
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "photo.2.fill",
                            iconColor: .claroWarning,
                            title: "Similar Photos",
                            subtitle: "Coming soon"
                        )
                        .padding(.horizontal)

                        ClaroToolRow(
                            icon: "video.fill",
                            iconColor: .claroCyan,
                            title: "Duplicate Videos",
                            subtitle: "Coming soon"
                        )
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: ClaroSpacing.xxl)
            }
            .padding(.top, ClaroSpacing.md)
        }
        .sheet(isPresented: $showReview) {
            DuplicateReviewView(service: service)
        }
        .task { await service.scan() }
        .onAppear {
            if service.pendingReview {
                service.pendingReview = false
                // Brief delay so any dismissal animation ahead of us completes.
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
                colors: [Color(hex: "#1A0A3E"), Color(hex: "#0A1628")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.claroViolet.opacity(0.3))
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .offset(x: 80, y: -30)

            VStack(spacing: ClaroSpacing.sm) {
                if service.isScanning {
                    // Scanning state
                    VStack(spacing: ClaroSpacing.md) {
                        ProgressView()
                            .tint(Color.claroVioletLight)
                            .scaleEffect(1.4)
                        Text("Scanning your library…")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("This may take a moment")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else if service.scanComplete && service.totalDuplicates == 0 {
                    // All clean
                    VStack(spacing: ClaroSpacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.claroSuccess)
                        Text("All Clean!")
                            .font(.claroTitle2())
                            .foregroundStyle(.white)
                        Text("No duplicate photos found")
                            .font(.claroCaption())
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(ClaroSpacing.xl)

                } else {
                    // Results
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.claroVioletLight)

                    Text("\(service.totalDuplicates) duplicates found")
                        .font(.claroTitle2())
                        .foregroundStyle(.white)

                    Text("\(service.reclaimableFormatted) can be reclaimed")
                        .font(.claroCaption())
                        .foregroundStyle(Color.white.opacity(0.55))

                    Button { showReview = true } label: {
                        Text("Review & Clean")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [.claroViolet, Color(hex: "#6D28D9")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                            .claroGlowShadow()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .disabled(service.totalDuplicates == 0)
                }
            }
            .padding(ClaroSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroViolet.opacity(0.25), lineWidth: 1)
        )
        .frame(minHeight: 180)
        .claroCardShadow()
    }
}

#Preview { PhotosView() }
