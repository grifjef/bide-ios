import Foundation
import Observation
import StoreKit

/// Optional tip jar — three non-consumable IAPs the user can buy if they
/// want to support Bide. None of them unlock anything. There is no
/// paywall, no feature gate, no "Pro." Bide stays free for everyone.
///
/// Honors the project constraint: free download, optional one-time IAP,
/// never a subscription.
///
/// Wraps StoreKit 2:
/// - `Product.products(for:)` loads the catalog from Apple's servers (or
///   the local `Bide.storekit` config when running in the sim with the
///   StoreKit Configuration File set in the scheme).
/// - `Transaction.currentEntitlements` populates `purchasedProductIDs`
///   so the UI can render "Thank you" instead of a buy button on a
///   product the user already tipped.
/// - A background task listens to `Transaction.updates` for purchases
///   that complete while the app is in the background.
@Observable
@MainActor
final class TipJarStore {
    /// Stable product IDs. Must match the App Store Connect entries (TBD)
    /// and the productID values in Bide.storekit. Renaming a case is an
    /// App Store migration — old receipts wouldn't match.
    enum TipID: String, CaseIterable {
        case small  = "com.bidephoto.bide.tip.small"
        case medium = "com.bidephoto.bide.tip.medium"
        case large  = "com.bidephoto.bide.tip.large"
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var loadState: LoadState = .idle
    private(set) var lastError: String?

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// StoreKit 2 transaction-update subscription. Held so a long-lived
    /// reference keeps it alive for the app lifetime.
    private var updatesTask: Task<Void, Never>?

    init() {
        // Spin up the transaction-update listener immediately so a
        // background-completed purchase (App Store popup races sleep,
        // user dismisses, transaction finalizes) lands in our state.
        // No deinit cancel: the [weak self] capture means the iteration
        // exits naturally on the next transaction once we deallocate.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    /// Load the product catalog. Idempotent — re-callable after a network
    /// failure to retry.
    func loadProducts() async {
        loadState = .loading
        lastError = nil
        do {
            let ids = Set(TipID.allCases.map(\.rawValue))
            let fetched = try await Product.products(for: ids)
            // Stable display order: small → medium → large.
            products = fetched.sorted { a, b in
                priorityRank(of: a.id) < priorityRank(of: b.id)
            }
            await refreshPurchases()
            loadState = .loaded
        } catch {
            lastError = error.localizedDescription
            loadState = .failed
        }
    }

    /// Buy a tip. The caller awaits the result; the published
    /// `purchasedProductIDs` set updates if Apple confirms the purchase.
    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failedVerification
                }
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                return .succeeded
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Restore — re-checks `Transaction.currentEntitlements`. Used by the
    /// "Restore purchases" button Apple requires for non-consumables.
    func restorePurchases() async {
        await refreshPurchases()
    }

    func isPurchased(_ id: TipID) -> Bool {
        purchasedProductIDs.contains(id.rawValue)
    }

    // MARK: - Private

    private func refreshPurchases() async {
        var found: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            found.insert(transaction.productID)
        }
        purchasedProductIDs = found
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        purchasedProductIDs.insert(transaction.productID)
        await transaction.finish()
    }

    private func priorityRank(of id: String) -> Int {
        switch id {
        case TipID.small.rawValue:  return 0
        case TipID.medium.rawValue: return 1
        case TipID.large.rawValue:  return 2
        default:                    return Int.max
        }
    }
}

/// Outcome of a single tip purchase attempt. Surfaces in the view.
enum PurchaseOutcome: Equatable {
    case succeeded
    case userCancelled
    case pending
    case failed(String)
    case failedVerification

    var isSuccess: Bool {
        if case .succeeded = self { return true }
        return false
    }
}
