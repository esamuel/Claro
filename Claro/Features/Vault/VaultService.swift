import CryptoKit
import Foundation
import LocalAuthentication
import Observation
import Photos
import Security
import UIKit

// MARK: - VaultItem

struct VaultItem: Identifiable, Codable {
    let id:        UUID
    let filename:  String
    let importedAt: Date
    let fileSize:  Int64
}

// MARK: - VaultService

@Observable
@MainActor
final class VaultService {

    // MARK: - State

    private(set) var items:      [VaultItem] = []
    private(set) var isUnlocked  = false
    private(set) var isLoading   = false
    private(set) var lockMessage = "Unlock to access your Private Vault"

    // MARK: - Private

    private var symmetricKey: SymmetricKey?

    private var vaultDir: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaroVault", isDirectory: true)
    }

    // MARK: - Init

    init() {
        // Directory creation is fast — keep it synchronous
        try? FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        // Disk I/O deferred to a background thread so it never blocks the first frame
        Task { await loadIndexAsync() }
    }

    // MARK: - Lock / Unlock

    func unlock() async throws {
        let ctx = LAContext()
        var error: NSError?
        let available = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        guard available else {
            throw VaultError.biometryUnavailable(error?.localizedDescription ?? "Authentication unavailable")
        }

        try await ctx.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock your Private Vault"
        )

        symmetricKey = try loadOrCreateKey()
        isUnlocked   = true
    }

    func lock() {
        symmetricKey = nil
        isUnlocked   = false
    }

    // MARK: - Import

    /// Import raw image data directly (from PhotosPicker transferable).
    func importData(_ imageData: Data, filename: String) async throws {
        guard let key = symmetricKey else { throw VaultError.locked }

        let id = UUID()

        // Encrypt and write full image
        let cipherFull = try encrypt(imageData, key: key)
        try cipherFull.write(to: vaultFile(id: id))

        // Generate and encrypt thumbnail
        if let thumb     = makeThumbnail(from: imageData),
           let thumbData = thumb.jpegData(compressionQuality: 0.6) {
            let cipherThumb = try encrypt(thumbData, key: key)
            try cipherThumb.write(to: thumbFile(id: id))
        }

        let item = VaultItem(
            id:         id,
            filename:   filename,
            importedAt: Date(),
            fileSize:   Int64(imageData.count)
        )
        items.insert(item, at: 0)
        saveIndex()
    }

    // MARK: - Remove originals from Photo Library

    /// Deletes the original PHAssets from the user's Photo Library.
    /// iOS will show its own system confirmation sheet before deleting.
    func deleteOriginalsFromLibrary(identifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    // MARK: - Delete from Vault

    func delete(_ item: VaultItem) {
        try? FileManager.default.removeItem(at: vaultFile(id: item.id))
        try? FileManager.default.removeItem(at: thumbFile(id: item.id))
        items.removeAll { $0.id == item.id }
        saveIndex()
    }

    // MARK: - Read

    func loadThumbnail(_ item: VaultItem) async -> UIImage? {
        guard let key = symmetricKey else { return nil }
        let url = thumbFile(id: item.id)
        return await Task.detached(priority: .userInitiated) {
            guard let data  = try? Data(contentsOf: url),
                  let plain = try? Self.decryptStatic(data, key: key)
            else { return nil }
            return UIImage(data: plain)
        }.value
    }

    func loadFullImage(_ item: VaultItem) async -> UIImage? {
        guard let key = symmetricKey else { return nil }
        let url = vaultFile(id: item.id)
        return await Task.detached(priority: .userInitiated) {
            guard let data  = try? Data(contentsOf: url),
                  let plain = try? Self.decryptStatic(data, key: key)
            else { return nil }
            return UIImage(data: plain)
        }.value
    }

    // MARK: - File Paths

    private func vaultFile(id: UUID) -> URL { vaultDir.appendingPathComponent("\(id.uuidString).vault") }
    private func thumbFile(id: UUID) -> URL { vaultDir.appendingPathComponent("\(id.uuidString).thumb") }

    // MARK: - Index Persistence

    private var indexURL: URL { vaultDir.appendingPathComponent("index.json") }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        // Store index unencrypted — it contains only IDs, dates, sizes (no content).
        try? data.write(to: indexURL)
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let loaded = try? JSONDecoder().decode([VaultItem].self, from: data)
        else { return }
        items = loaded
    }

    private func loadIndexAsync() async {
        let url = indexURL
        let loaded = await Task.detached(priority: .background) {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([VaultItem].self, from: data)
            else { return [VaultItem]() }
            return decoded
        }.value
        items = loaded
    }

    // MARK: - Crypto

    private func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw VaultError.encryptionFailed }
        return combined
    }

    private func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        try Self.decryptStatic(data, key: key)
    }

    nonisolated private static func decryptStatic(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealed, using: key)
    }

    // MARK: - Key Management (Keychain)

    private let keychainAccount = "com.samueleskenasy.claro.vault-key"

    private func loadOrCreateKey() throws -> SymmetricKey {
        // Try to load from Keychain
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }

        // Create a new key and store it
        let newKey    = SymmetricKey(size: .bits256)
        let keyData   = newKey.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData   as String: keyData,
            // Accessible after first unlock — survives device restarts
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw VaultError.keychainFailed }
        return newKey
    }

    // MARK: - Helpers

    private func makeThumbnail(from data: Data) -> UIImage? {
        guard let src = UIImage(data: data) else { return nil }
        let size    = CGSize(width: 300, height: 300)
        let scale   = max(size.width / src.size.width, size.height / src.size.height)
        let newSize = CGSize(width: src.size.width * scale, height: src.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let origin = CGPoint(x: (size.width - newSize.width) / 2,
                                 y: (size.height - newSize.height) / 2)
            src.draw(in: CGRect(origin: origin, size: newSize))
        }
    }

    // MARK: - Errors

    enum VaultError: LocalizedError {
        case locked
        case importFailed
        case encryptionFailed
        case keychainFailed
        case biometryUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .locked:                return "Vault is locked."
            case .importFailed:          return "Could not import photo."
            case .encryptionFailed:      return "Encryption failed."
            case .keychainFailed:        return "Could not store encryption key."
            case .biometryUnavailable(let msg): return msg
            }
        }
    }
}
