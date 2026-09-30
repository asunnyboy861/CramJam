import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let monthlyID = "com.zzoutuo.CramJam.pro.monthly"
    static let yearlyID = "com.zzoutuo.CramJam.pro.yearly"
    static let lifetimeID = "com.zzoutuo.CramJam.pro.lifetime"
    static let creditsID = "com.zzoutuo.CramJam.credits.300"
    static let proIDs: Set<String> = [monthlyID, yearlyID, lifetimeID]
    static let allIDs: [String] = [monthlyID, yearlyID, lifetimeID, creditsID]

    @Published private(set) var isPro = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var hasLoadedProducts = false
    @Published var lastPurchaseMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.updateEntitlements()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.allIDs)
        } catch {
            products = []
        }
        hasLoadedProducts = true
    }

    func updateEntitlements() async {
        var pro = false
        for id in Self.proIDs {
            if case .verified(let transaction)? = await Transaction.currentEntitlement(for: id),
               transaction.revocationDate == nil {
                pro = true
                break
            }
        }
        isPro = pro
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    if transaction.productID == Self.creditsID {
                        lastPurchaseMessage = "Purchase complete. Your 300 cloud credits will be added to your account shortly."
                    } else {
                        lastPurchaseMessage = "Purchase complete. Welcome to CramJam Pro!"
                    }
                } else {
                    lastPurchaseMessage = "Purchase could not be verified."
                }
                await updateEntitlements()
            case .userCancelled:
                break
            case .pending:
                lastPurchaseMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastPurchaseMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastPurchaseMessage = "Restore failed: \(error.localizedDescription)"
        }
        await updateEntitlements()
        lastPurchaseMessage = isPro ? "Purchases restored." : "No active purchases found."
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
}
