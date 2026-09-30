# Capabilities Configuration

## Analysis
Based on operation guide analysis:
- Recording + transcription → Microphone permission, Speech Recognition permission, Background Modes (audio)
- Recording state on lock screen → Live Activities (Dynamic Island / Live Activity)
- Widget (due card count) → WidgetKit extension target + App Groups
- StoreKit 2 subscriptions/consumables → In-App Purchase capability (no portal setup needed for local testing; products configured in App Store Connect)
- CloudKit optional sync → iCloud/CloudKit (optional enhancement; app uses local SwiftData by default)
- Cloud calls to GLM proxy → Outgoing network (client, default-allowed)

## Auto-Configured Capabilities
| Capability | Status | Method |
|------------|--------|--------|
| Microphone permission (NSMicrophoneUsageDescription) | ✅ Configured | project.yml INFOPLIST_KEY |
| Speech Recognition permission (NSSpeechRecognitionUsageDescription) | ✅ Configured | project.yml INFOPLIST_KEY |
| Background Modes (audio) | ✅ Configured | project.yml INFOPLIST_KEY_UIBackgroundModes=audio |
| Live Activities (Dynamic Island) | ✅ Configured | project.yml INFOPLIST_KEY_NSSupportsLiveActivities=YES (+FrequentUpdates) |
| App Groups (group.com.zzoutuo.CramJam) | ✅ Configured | .entitlements in App + Widgets targets |
| WidgetKit extension (CramJamWidgets target) | ✅ Configured | xcodegen app-extension target, widgetkit-extension point |
| PrivacyInfo.xcprivacy | ✅ Configured | Both targets (UserDefaults CA92.1 + FileTimestamp C617.1) |
| Dark UI default | ✅ Configured | INFOPLIST_KEY_UIUserInterfaceStyle=Dark |

## Manual Configuration Required
| Capability | Status | Steps |
|------------|--------|-------|
| CloudKit container (optional sync) | ⏳ Optional | App works fully on local SwiftData. To enable iCloud sync later: Apple Developer portal → Identifiers → enable iCloud on com.zzoutuo.CramJam → add CloudKit container → add entitlement. Graceful degradation: local-only. |
| StoreKit products in App Store Connect | ⏳ Pending (store release only) | Create 4 products (see price.md). Local dev/testing works via StoreKit configuration file. |

## No Configuration Needed
- Push Notifications (guide uses local notifications only)
- HealthKit / Location / Siri / Watch (not in guide scope; Watch mark-tasks is P2, deferred)

## Verification
- Build succeeded after configuration: ✅ (xcodebuild simulator, 11.1s)
- All entitlements correct: ✅ (App Group in both targets)
- Signing verification (generic/platform=iOS): ✅ PASSED — all targets signed "Apple Development: he zhou (VX3Q75X27B)"
- DEVELOPMENT_TEAM: JP4TN5PTS3 baked at project level
- PrivacyInfo.xcprivacy: App + Widgets targets covered
