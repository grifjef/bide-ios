# Bide: Camera Roll Review

[![CI](https://github.com/grifjef/bide-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/grifjef/bide-ios/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-informational.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/iOS-17%2B-lightgrey.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)

> **Bide your time. Keep what matters.**
> A private, on-device photo review app for iPhone.

Bide helps you review the photos and videos cluttering your iPhone — large videos, old screenshots, similar shots, blurry ones — at your own pace, and safely move what you don't want to Recently Deleted, where it can be recovered for 30 days.

The name *bide* — "to dwell, to wait patiently" — is the whole product philosophy: take your time. Look twice. Nothing leaves your phone.

**No ads. No account. No subscription. No tracking. No cloud upload by us.**

---

## Why this exists

The iPhone photo cleanup category on the App Store is large, ugly, and mostly predatory. Scare-tactic warnings. Subscription gates. AI claims. One-tap mass deletion that nukes your kid's first birthday along with the duplicate menu screenshot.

People deserve better.

Bide takes the opposite stance: **conservative recommendations, explanations for every suggestion, nothing deleted without a Review Basket confirmation, and zero data leaves your phone.** It's the photo cleaner for people who don't trust photo cleaners.

## What it does

Eight focused modules, grouped on the dashboard by how much care each needs:

**Quick wins**
- **Exact Duplicates** — byte-for-byte identical copies, found in seconds
- **Screen Recordings** — usually the biggest disposable files in a library
- **Large Videos** — sorted by size; favorites and hidden videos protected

**Bulk review**
- **Screenshots** — grouped by month/year, sortable by chat / app / visual via on-device OCR
- **Live Photos** — convert any to a still and reclaim its ~40% video sidecar

**Careful review**
- **Similar Photos** — time-bucketed clusters with a suggested keeper and the reason
- **Blurry Shots** — conservative candidates; photos with faces are excluded
- **On This Day** — photos from today's calendar day in past years

Everything feeds into a **Review Basket** — nothing deletes until you confirm, and confirmation is two-step (Bide's prompt, then iOS's). Everything moved lands in Apple's Recently Deleted, recoverable for 30 days.

## Platform integration

- **Home Screen + Lock Screen widgets** show your lifetime reclaim total
- **App Intents + Siri** — "Find clutter in Bide", "On this day in Bide"
- **Spotlight** — search "duplicates" or "screen recordings" to jump straight in
- **Quick Actions** — long-press the icon for Find clutter / On this day / Review basket
- **Background refresh** keeps the dashboard current overnight

## What it doesn't do

- No "AI cleaner" claims
- No fake danger warnings or storage scare tactics
- No automatic mass deletion
- No subscriptions, in-app purchases, or paywalls
- No accounts or sign-ups
- No third-party analytics or ad SDKs
- No photo upload to any server we control
- No "delete forever" — always Recently Deleted

## Privacy

All analysis runs **on your iPhone**. Bide:

- has no backend
- does not upload your photos
- does not require an account
- does not include ad or tracking SDKs
- maintains only a local index for performance

The only diagnostics involved are Apple's own MetricKit, which you can disable in iOS Settings.

If you sync your library through iCloud Photos, Apple controls that — we don't touch it.

Full privacy policy: [bidephoto.com/privacy](https://grifjef.github.io/bide-ios/privacy/) (also in [docs/privacy-policy.md](./docs/privacy-policy.md)).

## Status

**v1.0 submitted to the App Store** (in review). **v1.1 / v1.2 in active development** on `main` — see [ROADMAP.md](./ROADMAP.md) and [CHANGELOG.md](./CHANGELOG.md). [PLAN.md](./PLAN.md) holds the original phased delivery plan; [product/spec.md](./product/spec.md) is the full product specification.

## Tech stack

- **Swift 5.10** + **SwiftUI**, iOS 17+ (strict concurrency)
- **PhotoKit** for photo library access (+ `PHCachingImageManager` prewarming)
- **Vision** for image similarity (feature prints) + face protection
- **SwiftData** for the local index
- **WidgetKit** for Home Screen + Lock Screen widgets (App Group shared store)
- **App Intents** + **CoreSpotlight** for Siri / Shortcuts / Spotlight
- **BackgroundTasks** (`BGAppRefreshTask`) for overnight refresh
- **MetricKit** for diagnostics (no third-party SDKs, ever)
- **XCTest** + **XCUITest** for testing (211 unit + 1 UI)
- **xcodegen** for the project; **SwiftLint** (strict) in CI

## Building

Bide uses **xcodegen** to keep the Xcode project source-controlled and merge-friendly — `Bide.xcodeproj/` is gitignored; `project.yml` is the source of truth.

```bash
# One-time setup
brew install xcodegen

# Generate the Xcode project from project.yml
xcodegen generate

# Build for Simulator
xcodebuild build \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

# Run unit + UI tests
xcodebuild test \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO

# Open in Xcode for interactive work
open Bide.xcodeproj
```

The `.claude/skills/ios-build/` skill contains the full set of build/archive shortcuts including signing flags, scheme listing, and DerivedData reset commands.

## Contributing

This is an early-stage solo project. Bug reports and thoughtful issue threads welcome; pull requests are best discussed first via issue.

## License

MIT — see [LICENSE](./LICENSE).
