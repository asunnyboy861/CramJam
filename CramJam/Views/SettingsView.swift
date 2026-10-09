import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var glm: GLMService
    @EnvironmentObject private var cloudConsent: CloudConsentCenter

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "en-US"
    @AppStorage("noteLanguage") private var noteLanguage = "English"
    @AppStorage("creditsBalanceDisplay") private var creditsDisplay = "—"
    @State private var byoKey = ""
    @State private var keySaved = false
    @State private var showPaywall = false
    @State private var byoPresetID = "glm"
    @State private var byoBaseURL = ""
    @State private var byoModelID = ""
    @State private var isTestingConnection = false
    @State private var connectionResult: ConnectionResult?
    @State private var isApiKeyVisible = false

    enum ConnectionResult {
        case success
        case failure(String)
    }

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
                    Picker("Provider", selection: $byoPresetID) {
                        ForEach(BYOConfig.presets) { preset in
                            Text(preset.isCustom ? "\(preset.name)" : "\(preset.name) · \(preset.modelID)").tag(preset.id)
                        }
                    }
                    .onChange(of: byoPresetID) { _, newID in
                        if let preset = BYOConfig.preset(id: newID) {
                            byoBaseURL = preset.baseURL
                            byoModelID = preset.modelID
                        }
                        connectionResult = nil
                    }
                    if byoPresetID == "custom" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Base URL").font(.subheadline).foregroundStyle(.secondary)
                            TextField("https://api.example.com/chat/completions", text: $byoBaseURL)
                                .font(.subheadline)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model ID").font(.subheadline).foregroundStyle(.secondary)
                        TextField("model-name", text: $byoModelID)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            if isApiKeyVisible {
                                TextField("Enter API key", text: $byoKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Enter API key", text: $byoKey)
                            }
                            Button { isApiKeyVisible.toggle() } label: {
                                Image(systemName: isApiKeyVisible ? "eye" : "eye.slash")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Save configuration") {
                        let key = byoKey.trimmingCharacters(in: .whitespaces)
                        KeychainHelper.glmKey = key
                        BYOConfig.save(presetID: byoPresetID, baseURL: byoBaseURL.trimmingCharacters(in: .whitespaces), modelID: byoModelID.trimmingCharacters(in: .whitespaces))
                        byoKey = KeychainHelper.glmKey.isEmpty ? "" : "••••••••••••"
                        keySaved = true
                    }
                    .disabled(byoModelID.trimmingCharacters(in: .whitespaces).isEmpty
                              || (byoPresetID == "custom" && byoBaseURL.trimmingCharacters(in: .whitespaces).isEmpty))
                    if keySaved {
                        Label("Saved — key stored in Keychain", systemImage: "lock.checkmark")
                            .font(.caption)
                            .foregroundStyle(.appSuccess)
                    }
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTestingConnection { ProgressView().tint(.primary) }
                            else { Image(systemName: "antenna.radiowaves.left.and.right") }
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection
                              || KeychainHelper.glmKey.isEmpty
                              || byoModelID.trimmingCharacters(in: .whitespaces).isEmpty
                              || (byoPresetID == "custom" && byoBaseURL.trimmingCharacters(in: .whitespaces).isEmpty))
                    if let result = connectionResult {
                        switch result {
                        case .success:
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.appSuccess)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    if KeychainHelper.hasBYOKey {
                        Button("Remove key", role: .destructive) {
                            KeychainHelper.remove(account: KeychainHelper.byoKeyAccount)
                            byoKey = ""
                            connectionResult = nil
                        }
                    }
                } else {
                    HStack {
                        Text("Bring your own API key")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    Button("Unlock with Pro") { showPaywall = true }
                        .foregroundStyle(.appAccent)
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Your key, your quota — unlimited cloud generation billed to your own account. GLM, GPT, Gemini, DeepSeek, Claude or any OpenAI-compatible endpoint; pick the model you want.")
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

            Section {
                Toggle("Cloud generation", isOn: Binding(
                    get: { cloudConsent.hasGranted },
                    set: { enabled in
                        if enabled {
                            cloudConsent.showConsentSheet = true
                        } else {
                            cloudConsent.revoke()
                        }
                    }
                ))
                NavigationLink {
                    AIPrivacyInfoView()
                } label: {
                    Label("How your data is handled", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("AI Data & Privacy")
            } footer: {
                Text(cloudConsent.hasGranted
                     ? "Allowed: transcript text (and imported slides) are sent to CramJam's cloud relay, powered by the GLM model from Z.ai, or directly to your own provider when you use your own API key. Used only to generate your study materials."
                     : "Off: nothing leaves your device — generation uses on-device AI. Turn on to see exactly what is sent and to whom.")
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
            byoPresetID = UserDefaults.standard.string(forKey: "byoPresetID") ?? "glm"
            byoBaseURL = BYOConfig.baseURL
            byoModelID = BYOConfig.modelID
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

    private func testConnection() async {
        // Test against the in-editor values before they are saved
        let savedURL = UserDefaults.standard.string(forKey: "byoBaseURL")
        let savedModel = UserDefaults.standard.string(forKey: "byoModelID")
        let savedPreset = UserDefaults.standard.string(forKey: "byoPresetID")
        BYOConfig.save(presetID: byoPresetID,
                       baseURL: byoBaseURL.trimmingCharacters(in: .whitespaces),
                       modelID: byoModelID.trimmingCharacters(in: .whitespaces))
        isTestingConnection = true
        connectionResult = nil
        do {
            let key = byoKey.trimmingCharacters(in: .whitespaces).isEmpty
                ? KeychainHelper.glmKey
                : byoKey.trimmingCharacters(in: .whitespaces)
            let response = try await glm.testBYOConnection(key: key)
            connectionResult = response.uppercased().contains("OK") ? .success : .failure("Unexpected response: \(response)")
        } catch {
            connectionResult = .failure(error.localizedDescription)
        }
        isTestingConnection = false
        // Roll back so nothing is persisted until the user taps Save
        UserDefaults.standard.set(savedURL, forKey: "byoBaseURL")
        UserDefaults.standard.set(savedModel, forKey: "byoModelID")
        UserDefaults.standard.set(savedPreset, forKey: "byoPresetID")
    }
}
