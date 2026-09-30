# Git Repositories

## Main App (iOS Application)

| Item | Value |
|------|-------|
| **Repository Name** | CramJam |
| **Git URL** | git@github.com:asunnyboy861/CramJam.git |
| **Repo URL** | https://github.com/asunnyboy861/CramJam |
| **Visibility** | Public |
| **Primary Language** | Swift |
| **GitHub Pages** | ⏳ Pending (PHASE 7 — will be enabled from `/docs` folder) |
| **SSH Note** | Port 22 is blocked on this network — push via `GIT_SSH_COMMAND="ssh -o HostName=ssh.github.com -o Port=443" git push` |

## Cloud Proxy (GLM API Backend)

| Item | Value |
|------|-------|
| **Repository Name** | GLM-Cloudflare |
| **Git URL** | git@github.com:asunnyboy861/GLM-Cloudflare.git |
| **Repo URL** | https://github.com/asunnyboy861/GLM-Cloudflare |
| **Worker URL** | https://cramjam-api.calcs.top |
| **Status** | ✅ Deployed and verified (2026-09-30 end-to-end test: HTTP 200) |

## Policy Pages (Deployed from Main Repository /docs)

| Page | URL | Status |
|------|-----|--------|
| Landing Page | https://asunnyboy861.github.io/CramJam/ | ⏳ Pending |
| Support | https://asunnyboy861.github.io/CramJam/support.html | ⏳ Pending |
| Privacy Policy | https://asunnyboy861.github.io/CramJam/privacy.html | ⏳ Pending |
| Terms of Use | https://asunnyboy861.github.io/CramJam/terms.html | ⏳ Pending (subscription app) |

## Repository Structure

```
CramJam/
├── CramJam.xcodeproj/             # Xcode Project (App + Widgets targets)
├── CramJam/                       # iOS App Source Code
│   ├── App/                       # Entry point, root tabs, theme
│   ├── Views/                     # SwiftUI views (Home, Record, Review, Quiz, Paywall...)
│   ├── Models/                    # Flashcard, QuizItem, ExamPlan, CourseModels...
│   ├── Services/                  # GLMService, FSRScheduler, PurchaseManager, StreakStore...
│   ├── Pipeline/                  # PostClassPipeline
│   ├── Audio/                     # Recording & playback
│   └── Assets.xcassets/           # App icon & assets
├── CramJamWidgets/                # WidgetKit extension
├── CramJam.storekit               # StoreKit test configuration (subscription)
├── project.yml                    # xcodegen project definition
├── us.md                          # English operation guide
├── capabilities.md                # Capability & configuration reference
├── icon.md                        # Icon generation record
├── price.md                       # Monetization / IAP details
├── app_review_info.md             # App Store review notes
├── improvement_plan_1.md          # Improvement plan
├── nowgit.md                      # This file
├── keytext.md                     # ⚠️ EXCLUDED from repo (.gitignore — confidential ASO strategy)
└── COMPETITOR_REPORT.md           # ⚠️ EXCLUDED from repo (.gitignore — confidential competitor analysis)
```
