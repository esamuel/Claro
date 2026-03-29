import SwiftUI
import Photos

struct CompressionView: View {
    @Environment(PermissionsService.self) private var permissions
    @State private var service    = CompressionService()
    @State private var mediaType: MediaType = .photos
    @State private var photoQuality: PhotoQuality = .medium
    @State private var videoPreset: VideoPreset   = .hd720
    @State private var selectedIDs: Set<UUID>     = []
    @State private var compressionError: String?
    @State private var showError = false

    enum MediaType: String, CaseIterable {
        case photos = "Photos"
        case videos = "Videos"
    }

    private var currentItems: [CompressibleItem] {
        mediaType == .photos ? service.photos : service.videos
    }

    private var selectedItems: [CompressibleItem] {
        currentItems.filter { selectedIDs.contains($0.id) }
    }

    private var estimatedSavings: String {
        let factor = mediaType == .photos ? photoQuality.savingFactor : videoPreset.savingFactor
        return service.estimatedSavings(items: selectedItems, factor: factor)
    }

    var body: some View {
        ZStack {
            Color.claroBg.ignoresSafeArea()

            switch permissions.photoStatus {
            case .authorized, .limited:
                mainContent
            case .notDetermined:
                permissionRequest
            case .denied, .restricted:
                permissionDenied
            @unknown default:
                EmptyView()
            }

            if service.isCompressing {
                progressOverlay
            }
        }
        .navigationTitle("Compression")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            permissions.refresh()
            if permissions.photoStatus == .authorized || permissions.photoStatus == .limited {
                Task { await service.scan() }
            }
        }
        .onChange(of: permissions.photoStatus) { _, status in
            if status == .authorized || status == .limited {
                Task { await service.scan() }
            }
        }
        .onChange(of: mediaType) { _, _ in
            selectedIDs = []
        }
        .alert("Compression Failed", isPresented: $showError) {
            Button("OK") { compressionError = nil }
        } message: { Text(compressionError ?? "") }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: ClaroSpacing.lg) {

                    savingsCard
                        .padding(.horizontal)

                    // Media type picker
                    Picker("Media Type", selection: $mediaType) {
                        ForEach(MediaType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Quality picker
                    qualityPicker
                        .padding(.horizontal)

                    // Items list
                    if service.isScanning {
                        scanningState
                    } else if currentItems.isEmpty && service.scanComplete {
                        allCleanState
                    } else {
                        itemsList
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, ClaroSpacing.md)
            }

            if !selectedItems.isEmpty {
                actionBar
            }
        }
    }

    // MARK: - Savings Card

    private var savingsCard: some View {
        HStack(spacing: ClaroSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Potential savings")
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroTextMuted)

                HStack(spacing: 14) {
                    savingsStat(
                        icon: "photo.stack.fill",
                        label: "\(service.photos.count) photos",
                        value: service.estimatedSavings(items: service.photos, factor: PhotoQuality.medium.savingFactor),
                        color: .claroCyan
                    )
                    Divider().frame(height: 32).opacity(0.2)
                    savingsStat(
                        icon: "video.fill",
                        label: "\(service.videos.count) videos",
                        value: service.estimatedSavings(items: service.videos, factor: VideoPreset.hd720.savingFactor),
                        color: .claroSuccess
                    )
                }
            }

            Spacer()

            // Rescan
            Button {
                selectedIDs = []
                Task { await service.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.claroTextMuted)
                    .padding(10)
                    .background(Color.claroCard)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.claroCardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(ClaroSpacing.md)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.lg)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
        .claroCardShadow()
    }

    private func savingsStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.claroLabel())
                    .foregroundStyle(Color.claroTextMuted)
            }
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.claroTextPrimary)
        }
    }

    // MARK: - Quality Picker

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            ClaroSectionLabel(title: mediaType == .photos ? "Photo Quality" : "Video Resolution")

            if mediaType == .photos {
                HStack(spacing: 8) {
                    ForEach(PhotoQuality.allCases) { q in
                        qualityChip(
                            label: q.rawValue,
                            detail: q.detail,
                            isSelected: photoQuality == q
                        ) { photoQuality = q }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(VideoPreset.allCases) { p in
                        qualityChip(
                            label: p.rawValue,
                            detail: p.detail,
                            isSelected: videoPreset == p
                        ) { videoPreset = p }
                    }
                }
            }
        }
    }

    private func qualityChip(
        label: String, detail: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? Color.claroCyan : Color.claroTextSecondary)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? Color.claroCyan.opacity(0.8) : Color.claroTextMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.claroCyan.opacity(0.12) : Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.sm)
                    .strokeBorder(isSelected ? Color.claroCyan.opacity(0.4) : Color.claroCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Items List

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            HStack {
                ClaroSectionLabel(title: "\(currentItems.count) \(mediaType.rawValue) found")
                Spacer()
                Button {
                    if selectedIDs.count == currentItems.count {
                        selectedIDs = []
                    } else {
                        selectedIDs = Set(currentItems.map { $0.id })
                    }
                } label: {
                    Text(selectedIDs.count == currentItems.count ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.claroCyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ForEach(currentItems) { item in
                MediaItemRow(
                    item: item,
                    isSelected: selectedIDs.contains(item.id),
                    savingFactor: mediaType == .photos ? photoQuality.savingFactor : videoPreset.savingFactor
                ) {
                    if selectedIDs.contains(item.id) {
                        selectedIDs.remove(item.id)
                    } else {
                        selectedIDs.insert(item.id)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - States

    private var scanningState: some View {
        VStack(spacing: ClaroSpacing.md) {
            Spacer(minLength: 40)
            ProgressView()
                .scaleEffect(1.3)
                .tint(Color.claroCyan)
            Text("Scanning your library…")
                .font(.claroBody())
                .foregroundStyle(Color.claroTextSecondary)
            Spacer(minLength: 40)
        }
    }

    private var allCleanState: some View {
        VStack(spacing: ClaroSpacing.md) {
            Spacer(minLength: 60)
            ZStack {
                Circle()
                    .fill(Color.claroSuccess.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: mediaType == .photos ? "photo.stack.fill" : "video.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(Color.claroSuccess)
            }
            VStack(spacing: 6) {
                Text("All \(mediaType.rawValue.lowercased()) are optimized")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("No \(mediaType.rawValue.lowercased()) above the size threshold were found.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            VStack(spacing: 8) {
                Button {
                    Task { await compress() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Compress \(selectedItems.count) \(mediaType == .photos ? (selectedItems.count == 1 ? "photo" : "photos") : (selectedItems.count == 1 ? "video" : "videos")) · save ~\(estimatedSavings)")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color.claroCyan, Color(hex: "#0891B2")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                    .claroGlowShadow(color: .claroCyan)
                }
                .buttonStyle(.plain)

                Text("Originals will be deleted · \(selectedItems.count == 1 ? "A" : "One") system confirmation will appear")
                    .font(.claroLabel())
                    .foregroundStyle(Color.claroTextMuted)
            }
            .padding(.horizontal)
            .padding(.vertical, ClaroSpacing.md)
            .background(Color.claroBg)
        }
    }

    // MARK: - Progress Overlay

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: ClaroSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 90, height: 90)
                    Circle()
                        .trim(from: 0, to: service.progress)
                        .stroke(Color.claroCyan, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: service.progress)
                    Text("\(Int(service.progress * 100))%")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text(service.progressLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if service.progress == 1.0 && service.lastSavedBytes > 0 {
                        Text("Saved \(ByteCountFormatter.string(fromByteCount: service.lastSavedBytes, countStyle: .file)) from \(service.lastSavedCount) files")
                            .font(.claroCaption())
                            .foregroundStyle(Color.claroSuccess)
                    }
                }
            }
            .padding(ClaroSpacing.xl)
            .background(Color.claroCard.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.lg))
            .padding(.horizontal, 48)
        }
    }

    // MARK: - Permission Views

    private var permissionRequest: some View {
        VStack {
            Spacer()
            PermissionRequestView(
                icon: "photo.stack.fill",
                iconColor: .claroCyan,
                title: "No Photo Access",
                description: "To compress photos and videos, allow access to your library.",
                buttonTitle: "Allow Access"
            ) {
                Task { await permissions.requestPhotoAccess() }
            }
            Spacer()
        }
    }

    private var permissionDenied: some View {
        VStack {
            Spacer()
            PermissionDeniedView(
                icon: "photo.stack.fill",
                iconColor: .claroCyan,
                title: "No Photo Access",
                description: "To compress photos and videos, go to Settings and allow access."
            ) {
                permissions.openSettings()
            }
            Spacer()
        }
    }

    // MARK: - Compress

    private func compress() async {
        do {
            if mediaType == .photos {
                try await service.compressPhotos(selectedItems, quality: photoQuality)
            } else {
                try await service.compressVideos(selectedItems, preset: videoPreset)
            }
            selectedIDs = []
        } catch {
            compressionError = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Media Item Row

private struct MediaItemRow: View {
    let item: CompressibleItem
    let isSelected: Bool
    let savingFactor: Double
    let onTap: () -> Void

    @State private var thumb: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.claroCard)
                        .frame(width: 56, height: 56)
                    if let thumb {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: item.asset.mediaType == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.claroTextMuted.opacity(0.5))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.formattedSize)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.claroTextPrimary)
                    let saved = Int64(Double(item.fileSize) * savingFactor)
                    Text("Save ~\(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file))")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroSuccess)
                }

                Spacer()

                // Checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.claroCyan : Color.claroCardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Color.claroCyan)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            .padding(12)
            .background(isSelected ? Color.claroCyan.opacity(0.07) : Color.claroCard)
            .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ClaroRadius.md)
                    .strokeBorder(isSelected ? Color.claroCyan.opacity(0.3) : Color.claroCardBorder, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .task { await loadThumb() }
    }

    private func loadThumb() async {
        let asset = item.asset
        thumb = await Task.detached(priority: .userInitiated) {
            await withCheckedContinuation { cont in
                let opts = PHImageRequestOptions()
                opts.isSynchronous      = false
                opts.deliveryMode       = .fastFormat
                opts.resizeMode         = .fast
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 112, height: 112),
                    contentMode: .aspectFill,
                    options: opts
                ) { image, _ in cont.resume(returning: image) }
            }
        }.value
    }
}

#Preview { CompressionView() }
