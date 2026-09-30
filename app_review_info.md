# App Review Information

## Demo / Testing Instructions for Apple Review

CramJam works immediately after download with no account and no API key:

1. Launch the app → complete the 60-second onboarding (choose language, create a course) or skip it.
2. Tap the large Record button on Home → grant Microphone + Speech Recognition permissions → record 30–60 seconds of speech (reading aloud is fine).
3. Tap Stop → the post-class pipeline generates notes, flashcards, and a quiz automatically. A local notification "Notes are ready!" appears.
4. Review flow: Home shows "Today: N cards due" → swipe through flashcards with Again/Hard/Good/Easy.
5. Tap any note bullet to jump back to the exact moment in the recording.
6. Cram tab: set an exam date to generate a countdown study plan.
7. Contact Support: Profile → Contact Support → submit (sends to our feedback backend).

### AI Backend Model (Important for Reviewers)
- The app is transcription-first: iOS on-device speech recognition produces the transcript at no cost.
- On iOS 26+ devices with Apple Intelligence, note outline drafting runs fully on-device (Apple FoundationModels) — no key, no account, no cost.
- Cloud "deep generation" (structured notes/flashcards/quiz enrichment, slide photo understanding) is OPTIONAL and runs through our own server proxy (Cloudflare Worker). The API key lives ONLY on our server — users never need to provide one. Official cloud usage is metered server-side by subscription credits.
- Pro users may optionally bring their own Z.ai/BigModel API key (Settings → AI Configuration → "Bring Your Own Key"). Keys are stored in the iOS Keychain, sent only to api.z.ai, and are never visible to us.
- The app does NOT sell API keys or AI usage. No specific AI provider (OpenAI/ChatGPT/etc.) is promoted in any user-facing UI or metadata.
- On-device features (recording, captions, review, FSRS scheduling, timestamp jump-back) are free forever and fully functional with zero configuration.

### Subscription Testing
StoreKit configuration file `CramJam.storekit` is bundled for sandbox testing:
- `com.zzoutuo.CramJam.pro.monthly` — $4.99/month
- `com.zzoutuo.CramJam.pro.yearly` — $29.99/year (7-day free trial)
- `com.zzoutuo.CramJam.pro.lifetime` — $59.99 one-time (on-device Pro unlock + BYO key)
- `com.zzoutuo.CramJam.credits.300` — $2.99 consumable (300 server-metered cloud generations)

## Required Links (In-App)
- Privacy Policy: https://asunnyboy861.github.io/CramJam/privacy.html
- Terms of Use (EULA): https://asunnyboy861.github.io/CramJam/terms.html
- Support Page: https://asunnyboy861.github.io/CramJam/support.html

These links are accessible from:
1. Paywall (below the Subscribe button)
2. Profile → Settings → Legal section

## Review Notes

### Recording & Privacy
- Audio is recorded and transcribed on-device. Raw audio and transcripts stay on the device unless the user explicitly triggers a cloud enhancement, which sends TEXT only (never audio).
- First-record consent notice: "Check your course policy and local consent requirements before recording."
- All AI output carries the disclaimer: "AI may make mistakes — tap any line to verify against the recording."

### AI Features (Hybrid: On-Device + Server Proxy)
- AI features use a hybrid model: Apple on-device models (free, default) + optional server-proxied cloud generation (metered by subscription credits) + optional "Bring Your Own API Key" mode.
- The app does NOT sell API keys or AI usage.
- No specific AI provider (ChatGPT/OpenAI) is promoted in the UI.
- Users with their own key get unlimited cloud generation; any API costs are paid directly by the user to their chosen provider.

### Subscription Value
- Subscription unlocks app features (unlimited deep note generation, bilingual notes, slide import, Cram Mode) — NOT "unlimited AI" (BYO key users already have unlimited).
- Transparent pricing: identical on the App Store page and in-app. Cancel in one tap via Settings → Apple ID → Subscriptions. Review is free forever.

### China App Store Compliance
This app does NOT include ChatGPT functionality or reference ChatGPT/OpenAI in any user-facing UI or metadata for the China storefront. The AI feature uses a generic hybrid model (on-device Apple Foundation Models + server proxy + generic "Bring Your Own API Key"). No specific AI provider is promoted or bundled.
