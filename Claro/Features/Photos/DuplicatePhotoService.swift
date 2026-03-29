import Photos
import Observation

// MARK: - Model

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let assets: [PHAsset]   // 2+ assets that are exact duplicates of each other

    /// Bytes freed if we keep only the largest-file copy and delete the rest.
    var reclaimableBytes: Int64 {
        let sorted = assets.sorted { $0.fileSize > $1.fileSize }
        return sorted.dropFirst().reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Service

@Observable
final class DuplicatePhotoService {

    var groups: [DuplicateGroup] = []
    var isScanning    = false
    var scanComplete  = false
    var error: String?
    /// Set to true by Smart Clean to trigger the review sheet when Photos tab appears.
    var pendingReview = false

    // Derived
    var totalDuplicates: Int      { groups.reduce(0) { $0 + max($1.assets.count - 1, 0) } }
    var reclaimableBytes: Int64   { groups.reduce(0) { $0 + $1.reclaimableBytes } }
    var totalReclaimableGB: Double { Double(reclaimableBytes) / 1_073_741_824 }
    var reclaimableFormatted: String { ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file) }

    // MARK: Scan

    @MainActor
    func scan() async {
        guard !isScanning else { return }
        isScanning   = true
        scanComplete = false
        error        = nil

        do {
            groups = try await Task.detached(priority: .userInitiated) {
                try Self.findDuplicates()
            }.value
        } catch {
            self.error = error.localizedDescription
        }

        isScanning   = false
        scanComplete = true
    }

    private static func findDuplicates() throws -> [DuplicateGroup] {
        let opts = PHFetchOptions()
        opts.includeAssetSourceTypes = [.typeUserLibrary]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: opts)

        // Group by (creationDate, pixelWidth, pixelHeight, fileSize) — identical on exact copies.
        var buckets: [DuplicateKey: [PHAsset]] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            let key = DuplicateKey(
                creationDate: asset.creationDate ?? .distantPast,
                width:  asset.pixelWidth,
                height: asset.pixelHeight,
                size:   asset.fileSize
            )
            buckets[key, default: []].append(asset)
        }

        return buckets.values
            .filter  { $0.count > 1 }
            .map     { DuplicateGroup(assets: $0) }
            .sorted  { $0.reclaimableBytes > $1.reclaimableBytes }   // biggest savings first
    }

    // MARK: Delete

    /// Deletes the given assets. iOS will show its own system confirmation alert.
    func delete(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
        await scan()   // refresh counts after deletion
    }
}

// MARK: - Helpers

private struct DuplicateKey: Hashable {
    let creationDate: Date
    let width: Int
    let height: Int
    let size: Int64
}

extension PHAsset {
    /// File size in bytes, read from PHAssetResource metadata (no KVO, no network).
    var fileSize: Int64 {
        PHAssetResource.assetResources(for: self)
            .compactMap { $0.value(forKey: "fileSize") as? Int64 }
            .first ?? 0
    }
}
