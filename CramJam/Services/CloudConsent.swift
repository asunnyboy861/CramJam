import Foundation
import SwiftUI

/// Central consent gate for cloud AI (Guideline 5.1.1(i) / 5.1.2(i)):
/// no personal data (transcript text, slide images) may leave the device
/// until the user has seen what is sent, who receives it, and explicitly allowed it.
@MainActor
final class CloudConsentCenter: ObservableObject {
    static let shared = CloudConsentCenter()

    @Published var showConsentSheet = false

    private static let stateKey = "cloudConsentState"
    private static let versionKey = "cloudConsentVersion"
    private static let currentVersion = 1

    private var pendingContinuation: CheckedContinuation<Bool, Never>?

    var hasGranted: Bool {
        UserDefaults.standard.string(forKey: Self.stateKey) == "granted"
            && UserDefaults.standard.integer(forKey: Self.versionKey) >= Self.currentVersion
    }

    var hasDecided: Bool {
        UserDefaults.standard.string(forKey: Self.stateKey) != nil
            && UserDefaults.standard.integer(forKey: Self.versionKey) >= Self.currentVersion
    }

    /// Suspend the calling cloud request until the user answers the consent sheet.
    /// Returns true only when the user explicitly allowed cloud generation.
    func waitForConsent() async -> Bool {
        if hasGranted { return true }
        if pendingContinuation != nil { return false }
        return await withCheckedContinuation { continuation in
            pendingContinuation = continuation
            showConsentSheet = true
        }
    }

    func grant() {
        UserDefaults.standard.set("granted", forKey: Self.stateKey)
        UserDefaults.standard.set(Self.currentVersion, forKey: Self.versionKey)
        finish(true)
    }

    func deny() {
        UserDefaults.standard.set("denied", forKey: Self.stateKey)
        UserDefaults.standard.set(Self.currentVersion, forKey: Self.versionKey)
        finish(false)
    }

    func revoke() {
        deny()
    }

    private func finish(_ allowed: Bool) {
        showConsentSheet = false
        pendingContinuation?.resume(returning: allowed)
        pendingContinuation = nil
    }
}
