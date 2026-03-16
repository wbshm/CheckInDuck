import Foundation
import Combine
import StoreKit

enum SubscriptionProductCatalog {
    nonisolated static let monthly = "com.wang.CheckInDuck.monthly"
    nonisolated static let yearly = "com.wang.CheckInDuck.yearly"

    nonisolated static let all = [monthly, yearly]
}

struct SubscriptionEntitlementSnapshot {
    let productID: String
    let expirationDate: Date?
    let revocationDate: Date?
}

@MainActor
final class StoreKitSubscriptionService: ObservableObject {
    nonisolated static let defaultProductIDs = SubscriptionProductCatalog.all

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isProcessingPurchase = false
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var errorMessage: String?

    private let subscriptionAccess: SubscriptionAccessService
    private let productIDs: [String]
    private var updatesTask: Task<Void, Never>?

    init(
        subscriptionAccess: SubscriptionAccessService,
        productIDs: [String] = defaultProductIDs
    ) {
        self.subscriptionAccess = subscriptionAccess
        self.productIDs = productIDs
        self.updatesTask = Task {
            await observeTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            products = fetchedProducts.sorted { $0.displayName < $1.displayName }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load subscription products."
        }
    }

    func purchase(_ product: Product) async {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                guard let transaction = verifiedTransaction(from: verificationResult) else {
                    errorMessage = "Purchase verification failed."
                    return
                }
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .pending:
                errorMessage = "Purchase is pending approval."
            case .userCancelled:
                errorMessage = nil
            @unknown default:
                errorMessage = "Purchase result is unknown."
            }
        } catch {
            errorMessage = "Purchase failed."
        }
    }

    func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            errorMessage = "Restore purchases failed."
        }
    }

    func refreshSubscriptionStatus() async {
        let tier = await resolveSubscriptionTier()
        subscriptionAccess.updateTier(tier)
        lastSyncAt = Date()
    }

    private func observeTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            guard let transaction = verifiedTransaction(from: verificationResult) else {
                continue
            }
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }

    private func resolveSubscriptionTier() async -> SubscriptionTier {
        var snapshots: [SubscriptionEntitlementSnapshot] = []

        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: verificationResult) else {
                continue
            }
            snapshots.append(
                SubscriptionEntitlementSnapshot(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate
                )
            )
        }

        return Self.resolvedTier(
            from: snapshots,
            productIDs: productIDs,
            now: Date()
        )
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }

    nonisolated static func resolvedTier(
        from snapshots: [SubscriptionEntitlementSnapshot],
        productIDs: [String],
        now: Date
    ) -> SubscriptionTier {
        for snapshot in snapshots {
            guard productIDs.contains(snapshot.productID) else {
                continue
            }
            guard snapshot.revocationDate == nil else {
                continue
            }
            if let expirationDate = snapshot.expirationDate, expirationDate < now {
                continue
            }
            return .premium
        }
        return .free
    }
}
