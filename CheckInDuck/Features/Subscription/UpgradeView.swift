import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject private var subscriptionAccess: SubscriptionAccessService
    @StateObject private var storeKitSubscriptionService: StoreKitSubscriptionService

    let entryPoint: UpgradeEntryPoint

    init(
        subscriptionAccess: SubscriptionAccessService,
        entryPoint: UpgradeEntryPoint = .settings
    ) {
        self._subscriptionAccess = ObservedObject(wrappedValue: subscriptionAccess)
        self.entryPoint = entryPoint
        self._storeKitSubscriptionService = StateObject(
            wrappedValue: StoreKitSubscriptionService(subscriptionAccess: subscriptionAccess)
        )
    }

    var body: some View {
        List {
            Section {
                Text(entryPoint.copy.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(entryPoint.copy.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.tr("Premium Benefits")) {
                benefitRow("Unlimited tasks")
                benefitRow("Full history access")
                benefitRow("Custom reminder lead time")
            }

            Section(L10n.tr("Plans")) {
                if subscriptionAccess.currentTier == .premium {
                    Label(L10n.tr("Premium is active"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task {
                            await purchasePreferredProduct()
                        }
                    } label: {
                        Text(L10n.tr("Upgrade Now"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        preferredProduct == nil ||
                        storeKitSubscriptionService.isProcessingPurchase ||
                        storeKitSubscriptionService.isRestoringPurchases
                    )

                    if storeKitSubscriptionService.isLoadingProducts {
                        ProgressView(L10n.tr("Loading Plans..."))
                    } else if storeKitSubscriptionService.products.isEmpty {
                        Text(L10n.tr("No subscription products are available yet."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(storeKitSubscriptionService.products, id: \.id) { product in
                            Button {
                                Task {
                                    await storeKitSubscriptionService.purchase(product)
                                }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    Text(product.displayPrice)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(
                                storeKitSubscriptionService.isProcessingPurchase ||
                                storeKitSubscriptionService.isRestoringPurchases
                            )
                        }
                    }

                    if preferredProduct == nil {
                        Button(L10n.tr("Reload Plans")) {
                            Task {
                                await storeKitSubscriptionService.loadProducts()
                            }
                        }
                    }
                }

                Button(L10n.tr("Restore Purchases")) {
                    Task {
                        await storeKitSubscriptionService.restorePurchases()
                    }
                }
                .disabled(
                    storeKitSubscriptionService.isProcessingPurchase ||
                    storeKitSubscriptionService.isRestoringPurchases
                )

                if storeKitSubscriptionService.isProcessingPurchase {
                    Text(L10n.tr("Processing purchase..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if storeKitSubscriptionService.isRestoringPurchases {
                    Text(L10n.tr("Restoring purchases..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = storeKitSubscriptionService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(L10n.tr("Upgrade"))
        .task {
            if storeKitSubscriptionService.products.isEmpty {
                await storeKitSubscriptionService.loadProducts()
            }
            await storeKitSubscriptionService.refreshSubscriptionStatus()
        }
    }

    @ViewBuilder
    private func benefitRow(_ text: String) -> some View {
        Label(L10n.tr(text), systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
    }

    private var preferredProduct: Product? {
        guard
            let preferredProductID = UpgradePlanSelector.preferredProductID(
                from: storeKitSubscriptionService.products.map(\.id)
            )
        else {
            return nil
        }

        return storeKitSubscriptionService.products.first { product in
            product.id == preferredProductID
        }
    }

    private func purchasePreferredProduct() async {
        guard let preferredProduct else {
            return
        }
        await storeKitSubscriptionService.purchase(preferredProduct)
    }
}

#Preview {
    NavigationStack {
        UpgradeView(subscriptionAccess: SubscriptionAccessService())
    }
}
