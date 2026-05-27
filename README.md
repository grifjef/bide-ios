# Bide: Camera Roll Review

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

- **Large Videos** — find and review the biggest video files first
- **Screenshots** — group by date, bulk-review old ones safely
- **Similar Photos** — cluster near-duplicates, suggest a keeper, let you choose
- **Blurry Shots** — surface possible candidates, never assume

All four feed into a **Review Basket** — nothing deletes until you confirm. Everything moved to deletion lands in Apple's Recently Deleted, recoverable for 30 days.

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

Full privacy policy: [docs/privacy-policy.md](./docs/privacy-policy.md) *(coming soon)*

## Status

🚧 **In active development.** Initial release targeting App Store within ~1 week. See [PLAN.md](./PLAN.md) for the phased delivery plan and [product/spec.md](./product/spec.md) for the full product specification.

## Tech stack

- **Swift 5.10** + **SwiftUI**, iOS 17+
- **PhotoKit** for photo library access
- **Vision** for image similarity (feature prints)
- **SwiftData** for local index
- **MetricKit** for diagnostics (no third-party SDKs)
- **XCTest** + **XCUITest** for testing

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
