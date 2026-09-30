import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                tierList
                restoreSection
                legalSection
            }
            .padding()
        }
        .navigationTitle("CramJam Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Close") { dismiss() }
        }
        .task {
            await purchases.loadProducts()
            await purchases.updateEntitlements()
        }
        .alert(purchases.lastPurchaseMessage ?? "", isPresented: Binding(
            get: { purchases.lastPurchaseMessage != nil },
            set: { _ in purchases.lastPurchaseMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.appAccent)
            Text("Unlimited notes. Cram Mode. BYO key.")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Recording, captions, review and FSRS scheduling are free forever.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    @ViewBuilder
    private var tierList: some View {
        if purchases.products.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text(purchases.hasLoadedProducts ? "Products unavailable. Check your App Store connection." : "Loading plans…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                tierRow(id: PurchaseManager.yearlyID, badge: "Best Value · 7-day free trial")
                tierRow(id: PurchaseManager.monthlyID, badge: nil)
                tierRow(id: PurchaseManager.lifetimeID, badge: "One-time · BYO key")
                tierRow(id: PurchaseManager.creditsID, badge: "300 cloud generations")
            }
        }
    }

    private func tierRow(id: String, badge: String?) -> some View {
        Group {
            if let product = purchases.product(for: id) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        Spacer()
                        Text(product.displayPrice)
                            .font(.headline)
                            .foregroundStyle(.appAccent)
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appAccent.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    Button {
                        purchasingID = product.id
                        Task {
                            await purchases.purchase(product)
                            purchasingID = nil
                        }
                    } label: {
                        HStack {
                            if purchasingID == product.id {
                                ProgressView().tint(.white)
                            } else {
                                Text(id == PurchaseManager.creditsID ? "Buy credits" : "Subscribe")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(purchasingID != nil)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appMuted)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var restoreSection: some View {
        Button("Restore Purchases") {
            Task { await purchases.restore() }
        }
        .font(.subheadline)
    }

    private var legalSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Link("Privacy Policy", destination: URL(string: "https://asunnyboy861.github.io/CramJam/privacy.html")!)
                Link("Terms of Use", destination: URL(string: "https://asunnyboy861.github.io/CramJam/terms.html")!)
            }
            .font(.caption)
            Text("Subscriptions auto-renew until cancelled. Cancel anytime in Settings → Apple ID → Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 12)
    }
}
