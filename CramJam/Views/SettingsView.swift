import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var glm: GLMService

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "en-US"
    @AppStorage("noteLanguage") private var noteLanguage = "English"
    @AppStorage("creditsBalanceDisplay") private var creditsDisplay = "—"
    @State private var byoKey = ""
    @State private var keySaved = false
    @State private var showPaywall = false

    private let languages: [(id: String, label: String)] = [
        ("en-US", "English"), ("zh-CN", "中文"), ("es-ES", "Español"),
        ("fr-FR", "Français"), ("de-DE", "Deutsch"), ("ja-JP", "日本語"), ("ko-KR", "한국어")
    ]

    var body: some View {
        Form {
            Section("Pro") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(purchases.isPro ? "Pro" : "Free")
                        .foregroundStyle(purchases.isPro ? .appSuccess : .secondary)
                }
                if !purchases.isPro {
                    Button("Upgrade to Pro") { showPaywall = true }
                        .foregroundStyle(.appAccent)
                }
                Button("Restore Purchases") {
                    Task { await purchases.restore() }
                }
                if let message = purchases.lastPurchaseMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Cloud credits") {
                LabeledContent("Remaining credits", value: creditsDisplay)
                Text("Monthly and yearly plans include official cloud credits tracked on our servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if purchases.isPro {
                    SecureField("Z.ai / BigModel API key", text: $byoKey)
                    Button("Save key") {
                        KeychainHelper.glmKey = byoKey.trimmingCharacters(in: .whitespaces)
                        byoKey = KeychainHelper.glmKey.isEmpty ? "" : "••••••••••••"
                        keySaved = true
                    }
                    .disabled(byoKey.isEmpty)
                    if keySaved {
                        Label("Key stored in Keychain", systemImage: "lock.checkmark")
                            .font(.caption)
                            .foregroundStyle(.appSuccess)
                    }
                    if KeychainHelper.hasBYOKey {
                        Button("Remove key", role: .destructive) {
                            KeychainHelper.remove(account: KeychainHelper.byoKeyAccount)
                            byoKey = ""
                        }
                    }
                } else {
                    HStack {
                        Text("Bring your own GLM key")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    Button("Unlock with Pro") { showPaywall = true }
                        .foregroundStyle(.appAccent)
                }
            } header: {
                Text("AI")
            } footer: {
                Text("Your key, your quota — unlimited cloud generation billed to your own account.")
            }

            Section {
                HStack {
                    Text("Apple Intelligence")
                    Spacer()
                    Text(AppleFMService.isAvailable ? "Available (on-device)" : "Not available on this device")
                        .font(.caption)
                        .foregroundStyle(AppleFMService.isAvailable ? .appSuccess : .secondary)
                }
            } footer: {
                Text(AppleFMService.isAvailable
                     ? "On-device Apple Intelligence drafts notes for free. Cloud AI is used for glossary repair and slides."
                     : "Apple Intelligence is unavailable, so notes use cloud AI or the offline path. Recording and review are always free.")
            }

            Section("Recording") {
                Toggle("Ready notifications", isOn: $notificationsEnabled)
                Picker("Transcription language", selection: $transcriptionLanguage) {
                    ForEach(languages, id: \.id) { language in
                        Text(language.label).tag(language.id)
                    }
                }
                Picker("Notes language", selection: $noteLanguage) {
                    ForEach(["English", "Chinese", "Spanish", "French", "German", "Japanese", "Korean"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }

            Section("Legal") {
                Link(destination: URL(string: "https://asunnyboy861.github.io/CramJam/privacy.html")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://asunnyboy861.github.io/CramJam/terms.html")!) {
                    Label("Terms of Use", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://asunnyboy861.github.io/CramJam/support.html")!) {
                    Label("Support", systemImage: "lifepreserver")
                }
                NavigationLink {
                    ContactSupportView()
                } label: {
                    Label("Contact Support", systemImage: "envelope")
                }
            }

            Section("About") {
                LabeledContent(AppVersion.display, value: "")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .onAppear {
            byoKey = KeychainHelper.hasBYOKey ? "••••••••••••" : ""
            if let credits = glm.creditsBalance {
                creditsDisplay = "\(credits)"
            }
        }
        .onChange(of: glm.creditsBalance) { _, newValue in
            if let newValue {
                creditsDisplay = "\(newValue)"
            }
        }
    }
}
