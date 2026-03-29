import Photos
import Observation

// MARK: - Model

enum LargeMediaType { case video, largePhoto }

struct LargeMediaItem: Identifiable {
    let id         = UUID()
    let asset:     PHAsset
    let fileSize:  Int64
    let mediaType: LargeMediaType

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Service

@Observable
final class ICloudService {

    var items:        [LargeMediaItem] = []
    var isScanning    = false
    var scanComplete  = false
    var error:        String?
    var pendingReview = false

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }
    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    var videoCount: Int  { items.filter { $0.mediaType == .video      }.count }
    var photoCount: Int  { items.filter { $0.mediaType == .largePhoto }.count }

    // MARK: Scan

    @MainActor
    func scan() async {
        guard !isScanning else { return }
        isScanning   = true
        scanComplete = false
        error        = nil

        do {
            items = try await Task.detached(priority: .userInitiated) {
                try Self.findLargeMedia()
            }.value
        } catch {
            self.error = error.localizedDescription
        }

        isScanning   = false
        scanComplete = true
    }

    private static func findLargeMedia() throws -> [LargeMediaItem] {
        var result: [LargeMediaItem] = []

        // ── Videos (all — even short ones tend to be large) ─────────────
        let videoOpts = PHFetchOptions()
        videoOpts.includeAssetSourceTypes = [.typeUserLibrary]
        let videos = PHAsset.fetchAssets(with: .video, options: videoOpts)
        videos.enumerateObjects { asset, _, _ in
            let size = asset.fileSize
            guard size > 0 else { return }
            result.append(LargeMediaItem(asset: asset, fileSize: size, mediaType: .video))
        }

        // ── Large photos (screenshots, HDR, ProRAW — typically > 8 MB) ──
        let photoOpts = PHFetchOptions()
        photoOpts.includeAssetSourceTypes = [.typeUserLibrary]
        let largePhotoThreshold: Int64 = 8_000_000   // 8 MB
        let photos = PHAsset.fetchAssets(with: .image, options: photoOpts)
        photos.enumerateObjects { asset, _, _ in
            let size = asset.fileSize
            if size >= largePhotoThreshold {
                result.append(LargeMediaItem(asset: asset, fileSize: size, mediaType: .largePhoto))
            }
        }

        // Largest files first
        return result.sorted { $0.fileSize > $1.fileSize }
    }

    // MARK: Delete

    func delete(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
        await scan()
    }
}
