import AVFoundation
import Photos
import UIKit
import Observation

// MARK: - CompressibleItem

struct CompressibleItem: Identifiable {
    let id    = UUID()
    let asset: PHAsset
    let fileSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Quality Presets

enum PhotoQuality: String, CaseIterable, Identifiable {
    case high   = "High"
    case medium = "Medium"
    case low    = "Low"

    var id: String { rawValue }

    var jpegQuality: Double {
        switch self { case .high: return 0.78; case .medium: return 0.58; case .low: return 0.38 }
    }
    var savingFactor: Double {   // approximate fraction of original size saved
        switch self { case .high: return 0.40; case .medium: return 0.60; case .low: return 0.75 }
    }
    var detail: String {
        switch self {
        case .high:   return "Saves ~40% · barely visible"
        case .medium: return "Saves ~60% · slight reduction"
        case .low:    return "Saves ~75% · noticeable"
        }
    }
}

enum VideoPreset: String, CaseIterable, Identifiable {
    case hd1080 = "1080p"
    case hd720  = "720p"
    case sd480  = "480p"

    var id: String { rawValue }

    var exportPreset: String {
        switch self {
        case .hd1080: return AVAssetExportPreset1920x1080
        case .hd720:  return AVAssetExportPreset1280x720
        case .sd480:  return AVAssetExportPreset640x480
        }
    }
    var savingFactor: Double {
        switch self { case .hd1080: return 0.50; case .hd720: return 0.70; case .sd480: return 0.85 }
    }
    var detail: String {
        switch self {
        case .hd1080: return "Saves ~50% · full HD"
        case .hd720:  return "Saves ~70% · HD quality"
        case .sd480:  return "Saves ~85% · smaller screens"
        }
    }
}

// MARK: - Service

@Observable
@MainActor
final class CompressionService {

    private(set) var photos:      [CompressibleItem] = []
    private(set) var videos:      [CompressibleItem] = []
    private(set) var isScanning   = false
    private(set) var scanComplete = false

    // Compression state
    private(set) var isCompressing  = false
    private(set) var progress:       Double = 0      // 0…1
    private(set) var progressLabel   = ""
    private(set) var lastSavedBytes: Int64 = 0
    private(set) var lastSavedCount: Int   = 0

    // MARK: - Scan

    func scan() async {
        guard !isScanning else { return }
        isScanning   = true
        scanComplete = false

        let (p, v) = await Task.detached(priority: .userInitiated) {
            Self.fetchLargeMedia()
        }.value

        photos       = p
        videos       = v
        isScanning   = false
        scanComplete = true
    }

    // Fetch photos > 3 MB and videos > 10 MB, sorted largest first
    nonisolated private static func fetchLargeMedia() -> ([CompressibleItem], [CompressibleItem]) {
        let pOpts = PHFetchOptions()
        pOpts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let photoAssets = PHAsset.fetchAssets(with: pOpts)
        var photos: [CompressibleItem] = []
        photoAssets.enumerateObjects { asset, _, _ in
            let sz = asset.fileSize
            if sz > 3_000_000 { photos.append(CompressibleItem(asset: asset, fileSize: sz)) }
        }

        let vOpts = PHFetchOptions()
        vOpts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let videoAssets = PHAsset.fetchAssets(with: vOpts)
        var videos: [CompressibleItem] = []
        videoAssets.enumerateObjects { asset, _, _ in
            let sz = asset.fileSize
            if sz > 10_000_000 { videos.append(CompressibleItem(asset: asset, fileSize: sz)) }
        }

        return (
            photos.sorted { $0.fileSize > $1.fileSize },
            videos.sorted { $0.fileSize > $1.fileSize }
        )
    }

    // MARK: - Compress Photos

    func compressPhotos(_ items: [CompressibleItem], quality: PhotoQuality) async throws {
        guard !items.isEmpty else { return }
        isCompressing = true
        progress      = 0
        lastSavedBytes = 0
        lastSavedCount = 0

        let total = items.count
        var compressedImages: [(UIImage, PHAsset, Int64)] = []   // (compressed, original, originalSize)

        // Stage 1: load + compress (in memory)
        for (i, item) in items.enumerated() {
            progressLabel = "Compressing \(i + 1) of \(total)…"

            let data: Data = try await withCheckedThrowingContinuation { cont in
                let opts = PHImageRequestOptions()
                opts.version = .current
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .highQualityFormat
                PHImageManager.default().requestImageDataAndOrientation(
                    for: item.asset, options: opts
                ) { data, _, _, _ in
                    if let data { cont.resume(returning: data) }
                    else        { cont.resume(throwing: CompressionError.loadFailed) }
                }
            }

            guard let original = UIImage(data: data),
                  let jpegData = original.jpegData(compressionQuality: quality.jpegQuality),
                  let compressed = UIImage(data: jpegData)
            else { continue }

            let saved = max(0, item.fileSize - Int64(jpegData.count))
            lastSavedBytes += saved
            compressedImages.append((compressed, item.asset, item.fileSize))

            progress = Double(i + 1) / Double(total) * 0.6   // first 60% of progress
        }

        // Stage 2: save all compressed versions
        progressLabel = "Saving compressed photos…"
        for (i, (image, _, _)) in compressedImages.enumerated() {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            progress = 0.6 + Double(i + 1) / Double(compressedImages.count) * 0.25
        }

        // Stage 3: delete originals in one batch → single iOS system confirmation
        progressLabel = "Removing originals…"
        let assetsToDelete = compressedImages.map { $0.1 }
        if !assetsToDelete.isEmpty {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }
        }

        lastSavedCount = compressedImages.count
        progress       = 1.0
        progressLabel  = "Done"

        await scan()
        isCompressing = false
    }

    // MARK: - Compress Videos

    func compressVideos(_ items: [CompressibleItem], preset: VideoPreset) async throws {
        guard !items.isEmpty else { return }
        isCompressing  = true
        progress       = 0
        lastSavedBytes = 0
        lastSavedCount = 0

        let total = items.count
        var processedAssets: [PHAsset] = []

        for (i, item) in items.enumerated() {
            progressLabel = "Compressing video \(i + 1) of \(total)…"

            // Get AVAsset
            let avAsset: AVURLAsset = try await withCheckedThrowingContinuation { cont in
                let opts = PHVideoRequestOptions()
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .highQualityFormat
                PHImageManager.default().requestAVAsset(forVideo: item.asset, options: opts) { asset, _, _ in
                    if let urlAsset = asset as? AVURLAsset { cont.resume(returning: urlAsset) }
                    else { cont.resume(throwing: CompressionError.loadFailed) }
                }
            }

            guard let session = AVAssetExportSession(
                asset: avAsset, presetName: preset.exportPreset
            ) else { continue }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).mp4")
            session.outputURL      = tempURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            // Export (iOS 17 compatible)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                session.exportAsynchronously {
                    switch session.status {
                    case .completed: cont.resume()
                    default:         cont.resume(throwing: session.error ?? CompressionError.exportFailed)
                    }
                }
            }

            // Measure actual saved bytes before cleanup
            let newSize  = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? 0
            lastSavedBytes += max(0, item.fileSize - newSize)

            // Save to library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
            }
            try? FileManager.default.removeItem(at: tempURL)

            processedAssets.append(item.asset)
            progress = Double(i + 1) / Double(total) * 0.85
        }

        // Delete originals in one batch
        progressLabel = "Removing originals…"
        if !processedAssets.isEmpty {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(processedAssets as NSFastEnumeration)
            }
        }

        lastSavedCount = processedAssets.count
        progress       = 1.0
        progressLabel  = "Done"

        await scan()
        isCompressing = false
    }

    // MARK: - Helpers

    func estimatedSavings(items: [CompressibleItem], factor: Double) -> String {
        let bytes = Int64(Double(items.reduce(0) { $0 + $1.fileSize }) * factor)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Errors

    enum CompressionError: LocalizedError {
        case loadFailed, exportFailed
        var errorDescription: String? {
            switch self {
            case .loadFailed:   return "Could not load media file."
            case .exportFailed: return "Video export failed."
            }
        }
    }
}
