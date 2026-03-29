import StoreKit
import Observation

/// Handles all In-App Purchase logic using StoreKit 2.
/// Injected app-wide via `.environment(store)` in ClaroApp.
@Observable
final class StoreKitService {

    // ── Product IDs ── must match App Store Connect exactly ─────────────
    static let annualID   = "com.samueleskenasy.claro.annual"
    static let lifetimeID = "com.samueleskenasy.claro.lifetime"
    static let monthlyID  = "com.samueleskenasy.claro.monthly"

    // ── State ────────────────────────────────────────────────────────────
    private(set) var products: [Product]       = []
    private(set) var purchasedIDs: Set<String> = []
    private(set) var isLoading                 = false

    /// True when the user has any active Pro entitlement.
    /// DEBUG builds always return true so every feature can be tested without a purchase.
    var isPro: Bool {
        #if DEBUG
        return true
        #else
        return !purchasedIDs.isEmpty
        #endif
    }

    // Convenience accessors
    var annualProduct:   Product? { products.first { $0.id == Self.annualID   } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
    var monthlyProduct:  Product? { products.first { $0.id == Self.monthlyID  } }

    /// Savings % for Annual vs paying Monthly × 12. Falls back to 55 if products not loaded.
    var annualSavingsPercent: Int {
        guard let m = monthlyProduct, let a = annualProduct, m.price > 0 else { return 55 }
        let annualEquiv = m.price * 12
        let savings     = (annualEquiv - a.price) / annualEquiv
        let pct         = NSDecimalNumber(decimal: savings).doubleValue * 100
        return max(0, Int(pct.rounded()))
    }

    private var transactionListener: Task<Void, Error>?

    init() {
        // Transaction listener must start immediately to catch background renewals/revocations
        transactionListener = observeTransactionUpdates()
        // loadProducts() and refreshEntitlements() are triggered from ClaroApp
        // via .task{} after the first frame renders — keeps launch instant
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Load Products

    @MainActor
    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [
                Self.annualID, Self.lifetimeID, Self.monthlyID
            ])
        } catch {
            print("[StoreKit] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase. Returns `true` on success, `false` if cancelled/pending.
    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await refreshEntitlements()
            await tx.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            // Transaction is pending (e.g. Ask to Buy) — handle via transaction listener
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    /// Syncs with the App Store to restore any previous purchases.
    @MainActor
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Checks all current entitlements and updates `purchasedIDs`.
    @MainActor
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let tx = try? checkVerified(result), tx.revocationDate == nil {
                active.insert(tx.productID)
            }
        }
        purchasedIDs = active
    }

    // MARK: - Helpers

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    /// Listens for transaction updates (Ask to Buy approvals, renewals, revocations).
    private func observeTransactionUpdates() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let tx = try? self.checkVerified(result) {
                    await self.refreshEntitlements()
                    await tx.finish()
                }
            }
        }
    }

    // MARK: - Errors

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Transaction verification failed. Please contact support."
            }
        }
    }
}
