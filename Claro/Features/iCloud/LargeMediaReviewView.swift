import SwiftUI
import Photos

struct LargeMediaReviewView: View {
    let service: ICloudService
    @Environment(\.dismiss) private var dismiss

    @State private var selected:      Set<String> = []   // localIdentifiers
    @State private var isDeleting     = false
    @State private var deleteError:   String?
    @State private var filter:        MediaFilter = .all

    enum MediaFilter: String, CaseIterable {
        case all    = "All"
        case videos = "Videos"
        case photos = "Photos"
    }

    private var displayed: [LargeMediaItem] {
        switch filter {
        case .all:    return service.items
        case .videos: return service.items.filter { $0.mediaType == .video }
        case .photos: return service.items.filter { $0.mediaType == .largePhoto }
        }
    }

    private var selectedAssets: [PHAsset] {
        service.items
            .filter { selected.contains($0.asset.localIdentifier) }
            .map(\.asset)
    }

    private var selectedBytes: Int64 {
        service.items
            .filter { selected.contains($0.asset.localIdentifier) }
            .reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.claroBg.ignoresSafeArea()

                if service.items.isEmpty {
                    allCleanView
                } else {
                    itemList
                    if !selected.isEmpty { deleteBar }
                }
            }
            .navigationTitle("Large Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.claroCyan)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selected.count == displayed.count ? "Deselect All" : "Select All") {
                        if selected.count == displayed.count {
                            displayed.forEach { selected.remove($0.asset.localIdentifier) }
                        } else {
                            displayed.forEach { selected.insert($0.asset.localIdentifier) }
                        }
                    }
                    .font(.claroCaption())
                    .foregroundStyle(Color.claryCyan)
                }
            }
            .alert("Error", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: { Text(deleteError ?? "") }
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: ClaroSpacing.sm) {
                // Summary + info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(service.items.count) files · \(service.totalFormatted) total")
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                    InfoNote(text: "These are your biggest files by size — not duplicates or junk. Only delete what you no longer need.")
                }
                .padding(.horizontal)
                .padding(.top, ClaroSpacing.sm)

                // Filter
                Picker("Filter", selection: $filter) {
                    ForEach(MediaFilter.allCases, id: \.self) {
                        Text(LocalizedStringKey($0.rawValue)).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ForEach(displayed) { item in
                    LargeMediaRow(
                        item:       item,
                        isSelected: selected.contains(item.asset.localIdentifier)
                    )
                    .onTapGesture {
                        if selected.contains(item.asset.localIdentifier) {
                            selected.remove(item.asset.localIdentifier)
                        } else {
                            selected.insert(item.asset.localIdentifier)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
        }
    }

    // MARK: - Delete bar

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
                         : "Delete \(selected.count) items · free \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
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

    // MARK: - All clean

    private var allCleanView: some View {
        VStack(spacing: ClaroSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.claroCyan)
            VStack(spacing: 8) {
                Text("All Clean!")
                    .font(.claroTitle())
                    .foregroundStyle(Color.claroTextPrimary)
                Text("No large files found.")
                    .font(.claroBody())
                    .foregroundStyle(Color.claroTextSecondary)
            }
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 15)
                .background(Color.claroCyan)
                .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
                .claroGlowShadow(color: .claroCyan)
            Spacer()
        }
    }

    // MARK: - Actions

    private func performDelete() async {
        isDeleting = true
        do {
            try await service.delete(selectedAssets)
            selected.removeAll()
            if service.items.isEmpty { dismiss() }
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Row

private struct LargeMediaRow: View {
    let item:       LargeMediaItem
    let isSelected: Bool

    @State private var thumbnail: UIImage?
    private let thumbSize: CGFloat = 60

    var body: some View {
        HStack(spacing: ClaroSpacing.md) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.claryCyan : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                isSelected ? Color.claryCyan : Color.claroTextMuted.opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.claroCard
                        .overlay(
                            Image(systemName: item.mediaType == .video ? "video.fill" : "photo.fill")
                                .foregroundStyle(Color.claroTextMuted)
                        )
                }
            }
            .frame(width: thumbSize, height: thumbSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                // Video duration badge
                item.mediaType == .video
                    ? AnyView(
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(4)
                    )
                    : AnyView(EmptyView())
            )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.mediaType == .video ? "Video" : "Large Photo")
                    .font(.claroHeadline())
                    .foregroundStyle(Color.claroTextPrimary)
                if let date = item.asset.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.claroCaption())
                        .foregroundStyle(Color.claroTextMuted)
                }
            }

            Spacer()

            // Size badge
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.claryCyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.claryCyan.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(ClaroSpacing.md)
        .background(isSelected ? Color.claryCyan.opacity(0.07) : Color.claroCard)
        .clipShape(RoundedRectangle(cornerRadius: ClaroRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ClaroRadius.md)
                .strokeBorder(
                    isSelected ? Color.claryCyan.opacity(0.4) : Color.claroCardBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .task { thumbnail = await loadThumbnail() }
    }

    private func loadThumbnail() async -> UIImage? {
        let size = CGSize(width: thumbSize * 2, height: thumbSize * 2)
        let opts = PHImageRequestOptions()
        opts.deliveryMode    = .fastFormat
        opts.isNetworkAccessAllowed = false
        return await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: item.asset, targetSize: size,
                contentMode: .aspectFill, options: opts
            ) { img, _ in cont.resume(returning: img) }
        }
    }
}

// Convenience alias so we can write .claryCyan in this file too
private extension Color {
    static var claryCyan: Color { .claroCyan }
}
