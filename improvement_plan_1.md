# CramJam — Improvement Plan (Round 1)

Date: 2026-09-30 | Build: xcodebuild iOS Simulator iPhone 16 (OS 26.4.1) — **BUILD SUCCEEDED** (0 Swift warnings)

## Issue List (found in QA Phase A)

| # | Issue | Source | Severity | Status |
|---|-------|--------|----------|--------|
| 1 | `FSRS` SPM tag `1.0.0` does not exist (repo tags are v4.1.0/v5.0.0); FSRS-6 scheduler only exists on `main` (BasicSchedulerV6 + `defaultWv6`) | xcodegen/SPM resolution | Blocker | Fixed — pinned `branch: main`, verified real API (`FSRS(parameters:)`, `next(card:now:grade:)`, `getRetrievability(card:)`, `Rating`, top-level `Card`) |
| 2 | `@ObservedObject` used with SwiftData `@Model` classes (not `ObservableObject`) in CourseDetail/LectureDetail/Quiz/RepairSheet/SlideImport | compile error | Blocker | Fixed — switched to `@Bindable` |
| 3 | `SpeechTranscriber.Result` has **no** `isVolatile` member (SDK 27 interface verified) | compile error / API drift | Blocker | Fixed — volatile/final distinguished via `resultsFinalizationTime.isValid` + final-range dedupe guard |
| 4 | `SpeechTranscriber.supportedLocales` is `async` in SDK 27 | compile error | Blocker | Fixed — `await` |
| 5 | `Transaction.currentEntitlement(for:)` returns `VerificationResult<Transaction>?` (not `Transaction?`) | compile error | Blocker | Fixed — optional `.verified` pattern match |
| 6 | `ModernTranscriber` (iOS 26-only type) used as stored property of iOS 17 class | compile error | Blocker | Fixed — `AnyObject` ref + `@available` computed accessor |
| 7 | `LegacyTranscriber.finalize()` collided with `NSObject.finalize` | compile error | Blocker | Fixed — renamed `finishCollection()` |
| 8 | `SFSpeechRecognitionSegment` does not exist (correct type: `SFTranscriptionSegment`) | compile error | Blocker | Fixed |
| 9 | `#Predicate` comparing `$0.courseName == course.name` (model keypath inside predicate not allowed) | compile error | Blocker | Fixed — captured plain `String` |
| 10 | `.appAccent` etc. unresolved in `ShapeStyle` context (`foregroundStyle`) | compile error | Blocker | Fixed — `ShapeStyle where Self == Color` extension |
| 11 | `UNUserNotificationCenter` missing `import UserNotifications` | compile error | Blocker | Fixed |
| 12 | ContactSupport "Other" tile did not span full width (spec: 2-col grid, Other full-width) | us.md / task spec | Major | Fixed — 6 tiles in grid + full-width Other tile |
| 13 | Cross-feature dependency "Quiz wrong → Cram priority" not consumed by planner (us.md dependency table) | us.md | Major | Fixed — `CramPlanner.generate(priorityLectureDates:)` boosts cards from lectures with wrong quiz answers ahead of pure retrievability ordering |
| 14 | Glossary entry missing from Lecture detail toolbar (spec requires Quiz + Glossary entry there) | task spec | Minor | Fixed — toolbar NavigationLink added |
| 15 | `requestAuthorization()` result unused warning | compiler | Minor | Fixed |

## Post-fix verification
- grep TODO/FIXME/stub: only the allowed `TODO(production)` on the `devKey` line (widget `placeholder(in:)` is the WidgetKit-required protocol member, not a stub).
- grep hardcoded "1.0.0"/"1.0": none (version read via `Bundle.main.infoDictionary` in `AppVersion.display`).
- grep `freeGenerationsUsed`/`maxFreeGenerations`: none (server-tracked credits only; `creditsBalance` comes from Worker response fields, displayed as "—" until first response).
- `PurchaseManager` uses `Transaction.currentEntitlement(for:)` per product + full entitlement scan; `Transaction.updates` listener; `AppStore.sync()` restore.
- ContactSupportView sends the 5 required fields `{name, email, subject, message, app_name}`.
- DEVELOPMENT_TEAM baked at project level; PrivacyInfo.xcprivacy present in both targets; App Group entitlements intact.

## 7-Dimension Scores (after round 1)

| Dimension | Score | Notes |
|-----------|-------|-------|
| Feature completeness (F1–F12) | 9.0 | All 12 features implemented; Live Activity for recording state is config-only (in-app capsule UI implemented; no ActivityConfiguration widget) |
| Correctness / build health | 9.5 | BUILD SUCCEEDED, 0 Swift warnings; iOS 26 paths wrapped in availability; graceful L2→L1→offline degradation |
| Architecture / code quality | 9.0 | MVVM, one feature per module, zero comments (except allowed TODO), no networking in views, FSRS behind `FSRScheduler` |
| UI / UX | 8.5 | Dark-first, #FF6B35 accent, semantic colors, 4 tabs, one-hand record/review, streak grid, iPad maxWidth 720; no Liquid Glass-specific polish on iOS 26 |
| Compliance (IAP / legal / AI) | 9.0 | Paywall has all required disclosures + links; currentEntitlement checks; BYO key Pro-gated; consent + AI-mistakes disclaimers |
| Performance / stability | 8.5 | Incremental m4a write, background ModelContext pipeline, audio tap on serial queue; no profiling done |
| Security / privacy | 9.0 | Keychain for UUID + BYO key; only text sent to cloud; keychain service com.zzoutuo.CramJam |

## FINAL SCORES
- **TOTAL: 9.0 / 10**
- Verdict: release-candidate quality for TestFlight; runtime device pass (recording on real device, StoreKit sandbox purchase, Worker 200/402 paths) still recommended before App Store submission.

## Remaining backlog (non-blocking)
1. Recording Live Activity / Dynamic Island capsule (widget extension activity) — F2 enhancement.
2. CloudKit optional sync (deferred per capabilities.md).
3. Worker production auth: replace `devKey` with `appTransaction` JWS (TODO(production) marker in GLMService.swift).
4. iOS 26 SpeechAnalyzer asset pre-download (`AssetInventory`) for first-run latency on fresh devices.
5. Credits balance refresh: currently only from Worker response payloads; could add a dedicated balance query endpoint.
