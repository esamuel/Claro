import SwiftUI
import Photos

// MARK: - Review screen

struct DuplicateReviewView: View {
    let service: DuplicatePhotoService
    @Environment(\.dismiss) private var dismiss

    /// Maps groupID → localIdentifier of the asset the user wants to KEEP.
    /// All other assets in the group will be deleted.
    @State private var keepMap: [UUID: String] = [:]
    @State private var isDeleting = false
    @State private var deleteError: String?

    // Derived
    private var assetsToDelete: [PHAsset] {
        service.groups.flatMap { group in
            let keepID = keepMap[group.id]
            return group.assets.filter { $0.localIdentifier != keepID }
        }
    }

    private var deleteCount: Int   { assetsToDelete.count }
    private var deleteBytes: Int64 { assetsToDelete.reduce(0) { $0 + $1.fileSize } }
    private var deleteSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: deleteBytes, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.claroBg.ignoresSafeArea()

                if service.groups.isEmpty {
                    AllCleanView { dismiss() }
                } else {
                    groupList
                    if deleteCount > 0 { deleteBar }
                }
            }
            .navigationTitle("Review Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.claroViolet)
                }
            }
            .alert("Error", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
        .onAppear { initKeepMap() }
    }

    // MARK: Group list

    private var groupList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: ClaroSpacing.md) {
                // Summary header
                HStack {
                    Text("\(service.groups.count) duplicate groups · \(service.reclaimableFormatted) reclaimable")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, ClaroSpacing.sm)

                ForEach(service.groups) { group in
                    DuplicateGroupCard(
                        group: group,
                        keepID: Binding(
                            get: { keepMap[group.id] ?? group.assets.first?.localIdentifier ?? "" },
                            set: { keepMap[group.id] = $0 }
                        )
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)   // room for the delete bar
            }
        }
    }

    // MARK: Sticky delete bar

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            Button {
                Task { await performDelete() }
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text(isDeleting
                         ? "Deleting…"
                         : "Delete \(deleteCount) photos · free \(deleteSizeLabel)")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.claroDanger, Color(hex: "#B91C1C")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow(color: .claroDanger)
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .padding(.horizontal)
            .padding(.vertical, ClaroSpacing.md)
            .background(Color.claroBg)
        }
    }

    // MARK: Actions

    private func initKeepMap() {
        for group in service.groups where keepMap[group.id] == nil {
            // Default: keep the asset with the largest file (best quality)
            let best = group.assets.max(by: { $0.fileSize < $1.fileSize })
            keepMap[group.id] = best?.localIdentifier ?? group.assets.first?.localIdentifier
        }
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await service.delete(assetsToDelete)
            // If nothing left, dismiss
            if service.groups.isEmpty { dismiss() }
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Group card

private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @Binding var keepID: String

    private var savings: String {
        ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaroSpacing.sm) {
            HStack {
                Text("\(group.assets.count) copies")
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                Spacer()
                Text("Save \(savings)")
                    .font(.claroCaption())
                    .foregroundStyle(Color.claroSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.claroSuccess.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: ClaroSpacing.sm) {
                ForEach(group.assets, id: \.localIdentifier) { asset in
                    AssetTile(
                        asset: asset,
                        isKept: asset.localIdentifier == keepID
                    )
                    .onTapGesture { keepID = asset.localIdentifier }
                }
            }

            Text("Tap the photo you want to keep")
                .font(.claroCaption())
                .foregroundStyle(Color.claroTextMuted)
        }
        .padding(ClaroSpacing.md)
        .background(Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(Color.claroCardBorder, lineWidth: 1)
        )
        .claroCardShadow()
    }
}

// MARK: - Asset tile

private struct AssetTile: View {
    let asset: PHAsset
    let isKept: Bool

    @State private var thumbnail: UIImage?

    private let tileSize: CGFloat = 90

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.claroCard
                        .overlay(ProgressView().tint(Color.claroViolet))
                }
            }
            .frame(width: tileSize, height: tileSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isKept ? Color.claroSuccess : Color.claroDanger,
                        lineWidth: 2
                    )
            )

            // Badge
            ZStack {
                Circle()
                    .fill(isKept ? Color.claroSuccess : Color.claroDanger)
                    .frame(width: 22, height: 22)
                Image(systemName: isKept ? "checkmark" : "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: 6, y: -6)
        }
        .task { thumbnail = await loadThumbnail() }
        .animation(.easeInOut(duration: 0.2), value: isKept)
    }

    private func loadThumbnail() async -> UIImage? {
        let size = CGSize(width: tileSize * 2, height: tileSize * 2)
        let opts = PHImageRequestOptions()
        opts.deliveryMode    = .fastFormat
        opts.isNetworkAccessAllowed = false
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFill, options: opts
            ) { img, _ in cont.resume(returning: img) }
        }
    }
}

// MARK: - All clean state

private struct AllCleanView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.claroSuccess)
            VStack(spacing: 8) {
                Text("All Clean!")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("No duplicate photos found.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
            }
            Button("Done", action: onDone)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 15)
                .background(Color.claroViolet)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow()
            Spacer()
        }
    }
}
