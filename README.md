# KeepKind: Photo Declutter

> **Keep the memories. Clear the clutter.**
> A private, on-device photo review app for iPhone.

KeepKind helps you review the photos and videos cluttering your iPhone — large videos, old screenshots, similar shots, blurry ones — and safely move what you don't want to Recently Deleted, where it can be recovered for 30 days.

**No ads. No account. No subscription. No tracking. No cloud upload by us.**

---

## Why this exists

The iPhone photo cleanup category on the App Store is large, ugly, and mostly predatory. Scare-tactic warnings. Subscription gates. AI claims. One-tap mass deletion that nukes your kid's first birthday along with the duplicate menu screenshot.

People deserve better.

KeepKind takes the opposite stance: **conservative recommendations, explanations for every suggestion, nothing deleted without a Review Basket confirmation, and zero data leaves your phone.** It's the photo cleaner for people who don't trust photo cleaners.

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

All analysis runs **on your iPhone**. KeepKind:

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

## Brand family: Kind Apps

KeepKind is part of **Kind Apps** — simple public-good iOS apps with no ads, no accounts, no tricks. Sibling: **PageKind** (private scanner).

## Building

*(Build instructions will appear here once the Xcode project is scaffolded.)*

## Contributing

This is an early-stage solo project. Bug reports and thoughtful issue threads welcome; pull requests are best discussed first via issue.

## License

MIT — see [LICENSE](./LICENSE).
