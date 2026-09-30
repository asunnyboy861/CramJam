# CramJam - iOS Development Guide

> Source: TR-20260917-CramJam录音学习笔记App操作指南.MD (translated & enriched for LLM code generation)
> Report date: 2026-09-17 | Deployment target: iOS 17.0+ | Language: Swift 6 + SwiftUI

## Executive Summary

**CramJam = Press record in class. Walk out. Notes & flashcards are ready. AI plans your cramming before the exam.**

A US-market study app that replicates and beats Feynman AI (validated: $228K ARR / 200K users in 4 months). Target users: US college students + international students.

Key differentiators:
1. **Free unlimited on-device transcription** (iOS 26 SpeechAnalyzer; WER 2.12%, offline, no length cap) — competitors charge for cloud Whisper.
2. **Glossary-anchored term repair** via GLM-5.3-Flash — whitelist alignment, never free rewriting (fixes #1 one-star complaint: "alien language" transcripts).
3. **Per-word timestamps → tap any note line to jump back to the professor's words** (trust loop).
4. **Semester-first IA**: Course → Week → Lecture auto-organization.
5. **FSRS-6 spaced repetition + AI exam countdown planner (Cram Mode)**; review features free forever.
6. **Transparent 3-tier pricing** — the industry's #1 complaint source (deceptive pricing) is turned into a trust weapon.

## Competitive Analysis

| App | Strengths | Weaknesses | Our Advantage |
|-----|-----------|------------|---------------|
| Feynman AI | TikTok-driven growth, recording→notes→flashcards loop, $228K ARR | 7 confusing IAP tiers ($5.99/wk–$89.99), cloud Whisper cost, no term repair, no timestamps, "Critical bug fixes" spam in release notes | On-device free transcription, transparent pricing, glossary repair, FSRS-6 |
| Otter.ai | Mature transcription, real-time captions | 30-min free cap (standard lectures are 80–90 min), capture tool not a study system, no flashcards/FSRS | Unlimited recording, study closed-loop, free review forever |
| Listen AI / generic transcription apps | Cheap weekly plans | Hidden pricing → mass refund requests; Cal AI removed by Apple 2026-04 for hidden pricing | Store-page pricing transparency, one-tap cancel, "Review is free forever" promise |

## Apple Design Guidelines Compliance

- **Liquid Glass / iOS 26 materials**: SwiftUI native materials, Dynamic Island / Live Activity for recording state.
- **Dark-mode-first**: student evening study scene; accent `#FF6B35` (vibrant orange), success = mint green.
- **One-handed ergonomics**: single large Record button; 4 tabs max (Home / Courses / Cram / Profile); no infinite scroll.
- **Accessibility**: VoiceOver labels for all card actions; color-blind-safe shapes on review buttons (Again/Hard/Good/Easy); Dynamic Type support.
- **Privacy**: on-device-first = privacy as a selling point; only user-triggered cloud calls send TEXT (never audio); PrivacyInfo.xcprivacy declares "no audio collection".

## ⚠️ App Store Compliance — AI Features

### Apple Intelligence (Default Free AI Backend, L1)
- iOS 26+: FoundationModels (`LanguageModelSession`) generates note outline drafts on-device — free, offline, unlimited.
- iOS < 26 or model unavailable: skip L1 silently, go straight to L2 (GLM cloud) or degraded on-device output. Never show dead buttons.

### GLM Cloud (L2) via Cloudflare Worker Proxy
- **Deployed & tested (2026-09-17 + re-verified 2026-09-30)**:
  - Primary: `https://cramjam-api.calcs.top` (custom domain, works from CN dev machines and US)
  - Backup: `https://cramjam-proxy.iocompile67692.workers.dev` (US only; workers.dev is DNS-poisoned in CN)
  - Model: `glm-5.3-flash` (multimodal: text + vision)
- **Hard model behavior rules (MUST follow or calls break)**:
  1. `glm-5.3-flash` FORCES thinking; it cannot be disabled (error 1210). Always send `"thinking": {"level": "low"}`.
  2. `max_tokens` must be generous — reasoning tokens count against it. Text tasks ≥ 4096; vision/complex structured ≥ 8192. Otherwise `content` is empty with `finish_reason: "length"`.
  3. Structured output: system-prompt JSON contract + `"response_format": {"type": "json_object"}`. Client must IGNORE the `reasoning_content` field.
- **Request envelope** (Worker protocol):
  ```json
  {"userId": "<keychain-uuid>", "payload": {model, messages, thinking, max_tokens, response_format, temperature}, "devKey": "cramjam-dev-2026"}
  ```
  - Test period uses `devKey: cramjam-dev-2026` (Worker `DEV_MODE=1`). Production: replace with `appTransaction` (StoreKit 2 JWS) and remove DEV_MODE on the Worker.
  - Responses: 200 = GLM passthrough; 401 `invalid_receipt`; 402 `insufficient_credits`.
  - Credits: pro_monthly/pro_yearly plans are atomically debited (−1 per generate) server-side; lifetime/BYO users pass through without debit.
- **Dual routing** (`CloudRoute`): Pro user with no BYO key → Worker (official credits). Pro user with BYO key → direct `https://api.z.ai/api/paas/v4/chat/completions` with `Authorization: Bearer <key>` (unlimited, key in Keychain).
- Fallback iron rule: L2 unavailable / key invalid → auto-degrade to L1 on-device output; features never break (only term repair / vision / bilingual lost).

### Guideline 2.1(a) / 3.1.2(c)
- `canGenerate` logic: `isPro || hasBYOKey || onDevicePathAvailable` — **NO free-generation counters** (`freeGenerationsUsed` / `maxFreeGenerations` style dead code is FORBIDDEN).
- Free tier quota (3 deep generations/month) is tracked as **Cloud Credits on the SERVER (D1)**, never client-side gating of on-device features.
- Paywall MUST include: Privacy Policy link, Terms of Use (EULA) link, tier title/length/price, auto-renewal disclosure, "Cancel anytime in Settings → Apple ID → Subscriptions" + jump link.
- All AI output carries: "AI may make mistakes — tap any line to verify against the recording."
- First-launch notice: "Check your course policy / local consent requirements before recording."

## ⚠️ Feature Inventory (MANDATORY — 12 features from guide)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---------|--------------------|------------|------------|-------------|-------------|---------------------|
| F1 | One-tap lecture recording (survives lock/background, unlimited length) | Home → tap big Record button → recording state (Dynamic Island capsule + timer) → Stop | Mic audio via AVAudioEngine | Audio tap → AVAudioConverter (16kHz/mono/Float32) → AsyncStream<AnalyzerInput> → SpeechAnalyzer/SpeechTranscriber (iOS 26) or SFSpeechRecognizer fallback (17–25); background audio mode keeps alive | Live recording UI with elapsed time; m4a written incrementally | m4a file + Lecture row created at start | Record 5 min with screen locked → audio + transcript intact after unlock |
| F2 | Real-time caption overlay (<1s latency, bilingual option) | During recording, captions shown in-app and as Live Activity | Volatile transcription results | volatile results replace-only (never append); final results append | Rolling caption line | None (ephemeral) | Captions track speech with <1s perceived delay |
| F3 | Auto post-class output: outline notes + definition cards + key terms | Stop recording → pipeline runs (~30s) → local notification "Notes are ready!" | Final sentences (DB) | L1 Apple FM outline draft (free) → glossary match → L2 GLM structured JSON (note/flashcards/quiz) → attach sourceSentenceId | Outline note with headings/bullets/key terms/summary | NoteSection + noteJSON on Lecture | Note appears with ≥3 headings, key terms linked to glossary |
| F4 | Flashcard auto-generation + FSRS-6 spaced repetition | Note ready → cards ready; daily Home shows "N cards due" → swipe review (Again/Hard/Good/Easy) | GLM JSON flashcards (≤20/lecture) | FSRS-6 scheduler (swift-fsrs) computes due dates; rating writes back state | Review session UI; streak grid (GitHub-style year view) | Flashcard rows (due/stability/difficulty/lapses) | Review 10 cards → due dates advance per FSRS-6; streak increments |
| F5 | Glossary (auto-extract + user add/edit/delete + transcript repair) | Course detail → Glossary tab → add term; pipeline matches terms against transcript | User-entered or AI-extracted terms | Whitelist alignment prompt: GLM may ONLY replace mis-heard words with glossary entries; output diff (edits array) is reviewable/rollbackable | Corrected transcript with highlighted low-confidence fixes | GlossaryTerm rows (term/definition/hits) | Seeded wrong term in transcript gets replaced by glossary canonical form; non-glossary text untouched |
| F6 | Timestamp jump-back (note sentence ↔ audio) | Tap any note bullet/sentence → audio player seeks to sentence start and plays | Sentence start/end seconds + audioURL | AVAudioPlayer/AVPlayer seek | Playing audio from professor's exact words | Sentence rows (text/start/end/confidence) | Tap note line → playback starts at ±0.5s of spoken moment |
| F7 | Semester-first IA (Course → Week → Lecture) | Courses tab → Course → weeks → lectures list | Course name/color; lectures auto-assigned by date | Auto-group lectures into weeks (ISO week of lecture date) | Course/Week/Lecture hierarchy | Course/Lecture SwiftData cascade | New lecture lands in correct course+week automatically |
| F8 | Cram Mode (input exam date → AI countdown plan + 48h sprint pack) | Cram tab → pick course → set exam date → generate plan | examDate, dailyQuota | Countdown allocator: distribute due+weak cards (lowest retrievability + quiz-wrong cards) across remaining days | Day-by-day plan; 48h sprint pack before exam | ExamPlan row | Exam in 10 days → plan shows 10 daily quotas weighted to weak cards |
| F9 | Quiz (multiple choice + explanations) | Lecture detail → Quiz → answer 5 items | GLM JSON quiz items | Score, mark wrong answers' related cards for priority review | Quiz result with explanations | Quiz rows + wrong-answer flags | Quiz of 5 renders, scoring correct, wrong cards flagged |
| F10 | PDF/image slide import (photo PPT → notes) | Lecture → Import → camera/photo library → GLM vision | Image base64 (JPEG, <2MB) | GLM-5.3-Flash vision → structured notes merged into lecture | Extra note sections sourced "Slide" | NoteSection with source=slide | Photo of PPT slide yields bulleted notes section |
| F11 | Widget (today's due card count) | Add CramJam widget | App Group shared due count | Timeline provider recomputes daily | Widget shows "N cards due" | App Group UserDefaults | Widget count matches in-app Home badge |
| F12 | Note export (PDF / Markdown / Anki CSV) | Lecture → Export → choose format → Share sheet | Note + cards data | Render PDF (TextKit/SwiftUI ImageRenderer), Markdown string, Anki-compatible CSV | Shared file | None (share sheet) | Exported CSV imports into Anki without errors |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail | Interaction |
|---|--------|-------------|--------|-------------|
| S1 | F1 | Crash-safe recording | m4a written incrementally; final sentences committed to DB immediately; crash/kill never loses a lecture | automatic |
| S2 | F1 | Per-word timestamps | `attributeOptions: [.audioTimeRange]`; every Sentence stores start/end | automatic |
| S3 | F2 | Language selection in 60s onboarding | Choose transcription language + create first course; optional photo of class schedule | onboarding step |
| S4 | F3 | Low-confidence highlight + one-tap fix | Sentences with confidence < threshold highlighted; tap → 3 GLM candidate corrections (not free typing) | tap |
| S5 | F3 | Transparent consumption display | Each generation shows "On-device free ✓ / Cloud 3 credits" | automatic |
| S6 | F4 | Review gesture | One-hand vertical swipe cards; bottom 3-4 buttons with shape icons (color-blind safe) | swipe + tap |
| S7 | F4 | Streak grid | GitHub-style year grid of review days | view |
| S8 | F7 | Yesterday salvage | "Recordings from yesterday can still be processed" — late pipeline runs allowed | button |
| S9 | F8 | 48h sprint pack | Final 48h before exam: condensed high-yield card pack | view |
| S10 | F12 | Offline fallback | No network → on-device only; recording never blocked | automatic |
| S11 | Settings | BYO GLM Key (Pro only) | Paste Z.ai/BigModel key → stored in Keychain → unlimited cloud via direct route; "Your key, your quota" | settings form |
| S12 | Settings | Credits transparency | Show remaining official cloud credits (from Worker responses) | view |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|------------|--------|--------|-------------|---------|
| Recording → Pipeline | F1 stop | F3 | finalizedSentences + audioURL | Stop tapped |
| Pipeline → Flashcards | F3 JSON | F4 | flashcards array | Pipeline success |
| Glossary → Repair | F5 terms | F3 pipeline | glossary list | Each pipeline run |
| Sentence → Jump-back | F6 | F3 note bullets | sourceSentenceId | Tap note line |
| FSRS → Widget | F4 due dates | F11 | due count via App Group | Daily timeline refresh |
| Quiz wrong → Cram priority | F9 | F8 | wrong-answer card IDs | Plan generation |
| StoreKit → Cloud route | Paywall | L2 routing | isPro, credits | Every cloud call |

**VERIFICATION**: 12/12 guide features (F1–F12) present ✅

## Technical Architecture

- **Language**: Swift 6, SwiftUI, strict concurrency.
- **Min iOS**: 17.0. iOS-26-only APIs wrapped in `if #available(iOS 26, *)`.
- **Data**: SwiftData (CloudKit container optional sync).
- **Transcription**: iOS 26 `SpeechAnalyzer`/`SpeechTranscriber` (primary) → iOS 17–25 `SFSpeechRecognizer(requiresOnDeviceRecognition: true)` + buffer request with 10-min task restart chaining.
- **On-device AI (L1)**: FoundationModels `LanguageModelSession` (iOS 26+).
- **Cloud AI (L2)**: GLM-5.3-Flash via Worker proxy (see compliance section for protocol).
- **SRS**: SPM `open-spaced-repetition/swift-fsrs` (FSRS-6).
- **IAP**: StoreKit 2 (`Product.purchase()`, `Transaction.currentEntitlements`, AppTransaction JWS for Worker auth).
- **Widget**: WidgetKit + App Group.

## Module Structure

```
CramJam/
├── App/                    # CramJamApp.swift, RootTabView, onboarding router
├── Audio/                  # AudioEngine, TranscriptionService (iOS26 + fallback), AudioBufferConverter
├── Models/                 # SwiftData: Course, Lecture, Sentence, NoteSection, Flashcard, GlossaryTerm, ExamPlan, QuizItem
├── Pipeline/               # Chunker (semantic pauses), GlossaryEngine, NoteGenerator, CardGenerator, QuizGenerator
├── Services/               # CramJamCloud (Worker client), GLMService (BYO direct), AppleFMService, FSRScheduler, StoreService, KeyStore, ExportService
├── Views/                  # Home, Record, LectureDetail, Review, Cram, Paywall, Settings, Glossary, Quiz, Onboarding
├── Widgets/                # DueCardsWidget (App Group)
└── Packages/               # swift-fsrs via SPM
```

## ⚠️ Data Flow Diagram (iron rules from guide)

```
Recording layer (on-device)
  Mic (AVAudioEngine tap) → AudioBufferConverter (16k/mono/Float32)
    → AsyncStream<AnalyzerInput> → SpeechAnalyzer/SpeechTranscriber
    → volatile → caption overlay (replace-only)
    → final (+audioTimeRange) → Sentence rows → SwiftData  [RULE 1: persist immediately]
  m4a written incrementally during capture                  [RULE 1: never lose a lecture]

Post-class pipeline
  Sentences → Chunker (semantic pause/sentence boundaries, overlap; NEVER char-count) [RULE 3]
    → Apple FM outline draft (free, L1)
    → Glossary match (GlossaryTerm table)
    → GLM structured JSON via Worker or BYO direct (L2)     [RULE 5: auto-degrade to L1 if cloud fails]
    → Note{headings/bullets/key_terms/summary} + Flashcards(≤20) + Quiz(≤5)
    → every bullet/card carries sourceSentenceId            [RULE 2: full-chain timestamps]

Memory layer
  Flashcards → FSRS-6 scheduler → daily due set
  ExamPlan → Cram planner (countdown quota + lowest-retrievability weighting + quiz-wrong cards)
  Review ratings write back to FSRS state
```

**Data-flow verification**: every output (note bullet, card, quiz) traces back to Sentence rows + audioURL; every due date traces to FSRS state; credits trace to server D1. ✅

## Implementation Flow

1. Xcode project skeleton (xcodegen) + SwiftData models + green build.
2. Audio engine: recording, background/lock-screen keep-alive, m4a incremental writer.
3. Transcription: iOS 26 SpeechAnalyzer path + iOS 17–25 SFSpeechRecognizer fallback; timestamps; live captions.
4. Pipeline: chunker → Apple FM draft → GLM structured call (Worker + BYO dual route) → notes/cards/quiz persistence.
5. FSRS review flow + streak + Cram Mode planner.
6. Glossary engine + low-confidence repair UI.
7. Paywall (StoreKit 2, transparent pricing) + credits display + BYO key settings.
8. PDF/image import (GLM vision), export (PDF/MD/Anki CSV), Widget, polish.

## UI/UX Design Specifications

- **Theme**: dark default; accent `#FF6B35`; success mint green; Liquid Glass materials on iOS 26.
- **Navigation**: 4 tabs — Home / Courses / Cram / Profile.
- **Home**: one giant Record button + "Today: N cards due" card; no clutter.
- **Recording state**: Dynamic Island / top capsule with red dot + duration + one-line live caption; lock-screen Live Activity.
- **Review UI**: one-hand swipe; Again/Hard/Good/Easy with distinct shapes; year-view streak grid.
- **Trust design**: low-confidence lines highlighted with one-tap 3-candidate fix; every AI output has a "jump to source" affordance.
- **Copy tone**: short, US student voice: "Press record. Walk out. Notes ready."

## Code Generation Rules

- One feature per module; MV + `@Observable` services injected via environment; no networking/transcription logic inside Views.
- Store all prices/tokens server-side concepts in Int; dates UTC, display local.
- Every external call: timeout + 1 retry + graceful degradation UI.
- GLM calls MUST include `thinking: {level: low}`, `max_tokens ≥ 4096` (vision: 8192), `response_format json_object`; ignore `reasoning_content`.
- Recording consent + AI-mistakes disclaimers included at first launch and note screens.
- Version read dynamically via `Bundle.main.infoDictionary`.

## Build & Deployment Checklist

1. `xcodegen generate` → build iPhone + iPad simulators green.
2. Record 1-min simulated lecture → transcript + note + cards generated (Worker devKey test path).
3. StoreKit config file sandbox purchase test for all 4 products.
4. Widget timeline renders due count.
5. Archive-signed with Team JP4TN5PTS3.

## StoreKit Product IDs

| Product | ID | Price |
|---|---|---|
| Pro Monthly | `com.zzoutuo.CramJam.pro.monthly` | $4.99 |
| Pro Yearly (7-day trial) | `com.zzoutuo.CramJam.pro.yearly` | $29.99 |
| Pro Lifetime (on-device unlock + BYO key) | `com.zzoutuo.CramJam.pro.lifetime` | $59.99 |
| Credits Pack 300 | `com.zzoutuo.CramJam.credits.300` | $2.99 |

Pricing transparency copy: "Prices on the store page", "Cancel in one tap", "Review is free forever".
