import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.appAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CramJam")
                                .font(.headline)
                            Text(purchases.isPro ? "Pro member" : "Free plan — review is free forever")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Membership") {
                    if purchases.isPro {
                        Label("Pro is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.appSuccess)
                    } else {
                        NavigationLink {
                            PaywallView()
                        } label: {
                            Label("Upgrade to Pro", systemImage: "crown.fill")
                                .foregroundStyle(.appAccent)
                        }
                    }
                    NavigationLink {
                        PaywallView()
                    } label: {
                        Label("See plans", systemImage: "list.bullet.rectangle")
                    }
                }
                Section("Help") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    NavigationLink {
                        ContactSupportView()
                    } label: {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://asunnyboy861.github.io/CramJam/support.html")!) {
                        Label("Support Page", systemImage: "questionmark.circle")
                    }
                }
                Section("About") {
                    LabeledContent("App", value: "CramJam")
                    LabeledContent(AppVersion.display, value: "")
                }
            }
            .navigationTitle("Profile")
        }
    }
}
