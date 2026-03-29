import Foundation

struct StorageInfo {
    var usedGB: Double
    var totalGB: Double

    var freeGB: Double { totalGB - usedGB }
    var usedPercent: Double { guard totalGB > 0 else { return 0 }; return usedGB / totalGB }
    var usedFormatted: String { String(format: "%.1f", usedGB) }
    var freeFormatted: String { String(format: "%.1f", freeGB) }

    static let placeholder = StorageInfo(usedGB: 122.9, totalGB: 256)
}

// MARK: - StorageService

enum StorageService {
    /// Returns real device storage info; falls back to placeholder in Simulator.
    static func load() -> StorageInfo {
        let attrs   = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total   = (attrs?[.systemSize]     as? Int64) ?? 0
        let free    = (attrs?[.systemFreeSize] as? Int64) ?? 0
        let used    = total - free
        let totalGB = Double(total) / 1_073_741_824
        let usedGB  = Double(used)  / 1_073_741_824
        return totalGB > 10
            ? StorageInfo(usedGB: usedGB, totalGB: totalGB)
            : .placeholder
    }
}

struct CleaningSummary {
    var duplicatePhotos: Int
    var reclaimableGB: Double
    var duplicateContacts: Int
    var iCloudItems: Int

    static let placeholder = CleaningSummary(
        duplicatePhotos: 347,
        reclaimableGB: 2.4,
        duplicateContacts: 12,
        iCloudItems: 4
    )
}
