# Pricing Configuration

## Monetization Model: Subscription (IAP)

Transparent 3-tier freemium: on-device features (recording, live captions, flashcard review, FSRS scheduling, timestamp jump-back, course management) are **free forever**; Pro unlocks unlimited note generation, cloud credits, bilingual notes, slide import, and Cram Mode. A lifetime buyout covers on-device-only unlocking plus BYO-key unlimited cloud. A consumable credits pack is the bridge tier. Cloud credit accounting happens server-side (Cloudflare Worker + D1) — never client-gated.

## Subscription Group

- **Group Name**: CramJam Pro
- **Reference Name**: CramJam Pro
- **Products in group**: `com.zzoutuo.CramJam.pro.monthly`, `com.zzoutuo.CramJam.pro.yearly` (auto-renewable ONLY)

## Subscription Tiers (Auto-Renewable)

### 1. Monthly Subscription
- **Reference Name**: CramJam Pro Monthly
- **Product ID**: `com.zzoutuo.CramJam.pro.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $4.99 USD per month
- **Display Name**: `CramJam Pro Monthly` (19 chars, ≤35 ✅)
- **Description**: `Unlimited notes, 300 credits, Cram Mode` (40 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: CramJam Pro
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription (primary)
- **Reference Name**: CramJam Pro Annual
- **Product ID**: `com.zzoutuo.CramJam.pro.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $29.99 USD per year (50% savings vs monthly; less than $2.50/month)
- **Display Name**: `CramJam Pro Annual` (18 chars, ≤35 ✅)
- **Description**: `All Pro features, 400 credits monthly, trial` (45 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: CramJam Pro (same group as monthly)
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Non-Consumable)

### 1. Pro Lifetime
- **Reference Name**: CramJam Pro Lifetime
- **Product ID**: `com.zzoutuo.CramJam.pro.lifetime`
- **Type**: Non-consumable (one-time purchase, permanently unlocked)
- **Price**: $59.99 USD (one-time)
- **Display Name**: `CramJam Lifetime` (16 chars, ≤35 ✅)
- **Description**: `On-device Pro forever + bring your own key` (43 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required
- **Differentiation Note**: Lifetime unlocks ALL on-device Pro features and unlimited cloud generation ONLY via the user's own GLM key (BYO). It does NOT include official Cloud Credits — users who want server-managed credits choose Monthly/Yearly. No ongoing cost to us, so a buyout is compliant.

### 2. Credits Pack 300
- **Reference Name**: CramJam Credits 300
- **Product ID**: `com.zzoutuo.CramJam.credits.300`
- **Type**: Consumable (300 cloud generations, no expiry)
- **Price**: $2.99 USD
- **Display Name**: `300 Cloud Credits` (17 chars, ≤35 ✅)
- **Description**: `300 cloud generations for deep notes` (37 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ❌ N/A (consumable — balance lives server-side in D1)
- **Note**: Bridge tier for free users who occasionally want cloud depth without subscribing.

## Free Tier (Default)

- **Price**: Free
- **Features**:
  - Unlimited recording with lock-screen/background keep-alive
  - Real-time captions (on-device)
  - On-device transcription with per-word timestamps
  - Timestamp jump-back (tap note line → professor's words)
  - Flashcard review + FSRS-6 scheduling (free forever)
  - Streak grid and course management
  - 3 deep cloud generations per month (server-tracked credits)
- **Conversion hooks**:
  - Exam-season push: "Exam in 10 days — unlock Cram Mode"
  - Transparent meter: every generation shows "On-device free ✓ / Cloud N credits"
  - Paywall promise: "Review is free forever" — differentiator vs. every competitor

## Pro Features Unlocked (All Paid Tiers)

| Feature | Free | Pro (Monthly/Yearly) | Lifetime |
|---------|:----:|:--------------------:|:--------:|
| Recording + live captions | ✅ Free forever | ✅ | ✅ |
| FSRS review + streak | ✅ Free forever | ✅ | ✅ |
| Timestamp jump-back | ✅ Free forever | ✅ | ✅ |
| Unlimited note generation | 3/month (credits) | ✅ + 300–400 credits/mo | ✅ via BYO key only |
| Bilingual notes (mother-tongue) | ❌ | ✅ | ✅ via BYO key |
| PDF/image slide import (vision) | ❌ | ✅ | ✅ via BYO key |
| Cram Mode exam planner | ❌ | ✅ | ✅ |
| Widget due-card count | ✅ | ✅ | ✅ |
| BYO GLM key (unlimited cloud) | ❌ Pro-only entry | ✅ | ✅ |

## Free Trial

- **Duration**: 7 days
- **Type**: Free trial (auto-converts to paid subscription)
- **Available for**: Yearly subscription only (`com.zzoutuo.CramJam.pro.yearly`)

## Policy Pages Required

- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (REQUIRED — subscription apps must have Terms)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist

- [x] Auto-renewal terms will be included in Terms of Use
- [x] Cancellation instructions will be included in Support Page ("Cancel anytime in Settings → Apple ID → Subscriptions" + jump link in Settings)
- [x] Pricing clearly stated in PaywallView — identical to App Store page, no onboarding-end paywall ambush
- [x] Free trial terms included (7-day yearly trial)
- [x] Restore purchases functionality implemented (StoreKit 2 `Transaction.currentEntitlements`)
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] BYO Key model: subscription value = "Unlock Pro Features", NOT "Unlimited AI Generations"; BYO users get unlimited generation with their own key; `canGenerate = isPro || hasBYOKey || onDeviceAvailable`; no `freeGenerationsUsed`/`maxFreeGenerations` client dead-code — free cloud quota is server-tracked (Worker D1)
