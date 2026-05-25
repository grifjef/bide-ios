# CLAUDE.md — KeepKind iOS

> Project context for Claude Code sessions. Read this first when starting work on this repo.

## What this is

**KeepKind: Photo Declutter** — a native iOS app that helps people safely review and clear photo-roll clutter on their iPhone. On-device only, no ads/account/subscription/tracking. Part of the **Kind Apps** brand family (sibling: PageKind, a scanner).

Master plan: [PLAN.md](./PLAN.md)
Product spec (source of truth for product decisions): [product/spec.md](./product/spec.md)
Decisions log: [docs/decisions.md](./docs/decisions.md)

Live URL: *(App Store TBD once submitted)*

## Repo structure

```
/
├── KeepKind/                # Xcode project (to be scaffolded)
├── KeepKindTests/           # XCTest unit tests
├── KeepKindUITests/         # XCUITest UI tests
├── product/
│   └── spec.md              # full product specification
├── docs/
│   ├── decisions.md         # decision log
│   ├── architecture.md      # technical architecture (TBD)
│   ├── safety-model.md      # risk tiers (TBD)
│   ├── photokit-usage.md    # PhotoKit patterns (TBD)
│   ├── similar-photo-algorithm.md  # clustering approach (TBD)
│   ├── privacy-policy.md    # privacy policy copy (TBD)
│   └── app-store-listing.md # App Store listing copy (TBD)
├── .claude/
│   └── skills/              # Claude Code skills for this project
│       ├── ios-build/
│       ├── apple-deploy/
│       ├── sonarcloud-swift/
│       ├── photokit-snippets/
│       ├── jira-flow/
│       └── confluence-doc/
├── .github/
│   ├── workflows/
│   │   └── ci.yml           # GitHub Actions CI (macos-latest)
│   └── dependabot.yml
├── sonar-project.properties
├── .swiftlint.yml
├── PLAN.md                  # master delivery plan
├── README.md
└── CLAUDE.md                # this file
```

## Tech stack

- **Language:** Swift 5.10
- **UI:** SwiftUI
- **iOS deployment target:** 17.0
- **Photo access:** PhotoKit
- **Image analysis:** Vision (`VNGenerateImageFeaturePrintRequest`)
- **Persistence:** SwiftData (local index)
- **Diagnostics:** MetricKit (Apple-native — no Sentry/Firebase/Crashlytics)
- **Testing:** XCTest, XCUITest
- **Linting:** SwiftLint, swift-format
- **Dependency mgmt:** Swift Package Manager (SPM)

## Key commands

```bash
# Build for Simulator
xcodebuild build \
  -scheme KeepKind \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Run tests
xcodebuild test \
  -scheme KeepKind \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -enableCodeCoverage YES

# Lint
swiftlint --strict

# Archive (release)
xcodebuild archive \
  -scheme KeepKind \
  -configuration Release \
  -archivePath ./build/KeepKind.xcarchive

# Open in Xcode
open KeepKind.xcodeproj
```

See `.claude/skills/ios-build/` for the full set of build shortcuts.

## Deployment

- **Branch protection:** main requires CI green
- **TestFlight:** archived builds uploaded via Xcode or `xcrun altool` (see `.claude/skills/apple-deploy/`)
- **App Store:** submitted via App Store Connect

CI: GitHub Actions on `macos-latest`. Jobs: SwiftLint, build, test, SonarCloud scan.

## Design conventions

- **Voice:** calm, safe, respectful. Never alarmist. Never urgent. No "junk", "danger", "boost", "magic", "AI cleaner" language.
- **Color palette:** *(to confirm)* warm off-white background, muted sage green primary, dark teal accent
- **Typography:** SF Pro, Dynamic Type respected everywhere
- **Accessibility:** VoiceOver-clean, Dynamic Type-clean, contrast-checked from v1
- **Copy rules:**
  - Never "Delete forever" — use "Move to Recently Deleted"
  - Never "Best photo" — use "Suggested keeper"
  - Always explain recommendations ("Suggested because it is sharper", "Suggested because it is favorited")
  - Acknowledge Apple's 30-day Recently Deleted recovery window prominently

## Project management

- **GitHub:** [grifjef/keepkind-ios](https://github.com/grifjef/keepkind-ios) (public)
- **Jira:** project **KK** at [grifjef.atlassian.net](https://grifjef.atlassian.net)
- **Confluence:** space **KK** at [grifjef-1773158363073.atlassian.net/wiki](https://grifjef-1773158363073.atlassian.net/wiki)
- **SonarCloud:** [grifjef_keepkind-ios](https://sonarcloud.io/organizations/grifjef)

## Development process

For every feature / bug / enhancement:

1. **Plan** — Create Jira item under the right Epic. Set status `Dev In Progress` when starting.
2. **Branch** — `feature/KK-<id>-short-description` (e.g. `feature/KK-42-large-videos-deletion`).
3. **Implement + Test** — Code + XCTest. All checks must pass: SwiftLint, build, tests.
4. **Document** — Update relevant Confluence pages. Update CLAUDE.md if commands/architecture/conventions changed.
5. **PR** — Push. CI validates. Claude `/security-review` runs on PR.
6. **Complete** — Transition Jira item to `Done`. Merge.

## Quality gates and CI/CD

- **SwiftLint** — strict mode
- **xcodebuild build** — must succeed for iOS Simulator (iPhone 15)
- **xcodebuild test** — all tests pass, coverage uploaded to SonarCloud
- **SonarCloud** — Swift analyzer, runs via GitHub Action (Automatic Analysis disabled)
- **Dependabot** — weekly SPM updates
- **Claude `/security-review`** — runs on PRs

## Non-negotiable product principles

These come from the product spec and constrain everything:

1. **Never auto-delete memories.** App recommends; human decides.
2. **Every delete is reversible** (Recently Deleted, 30 days).
3. **No scare tactics in copy.**
4. **No photo uploads.** No third-party SDKs that touch user data.
5. **Conservative defaults around faces, favorites, hidden, recent (<30d), edited, Live Photos, album-tagged.**
6. **Always explain recommendations.**
7. **App must be VoiceOver- and Dynamic-Type-clean from v1.**

If a proposed change contradicts these, reject it or surface the conflict before implementing.

## Common gotchas

*(Will be populated as we discover them.)*

- **iCloud Photos:** assets may not be locally downloaded. Use `PHCachingImageManager` with `isNetworkAccessAllowed = false` for thumbnails; surface "needs download" state to user clearly.
- **`PHPhotoLibraryChangeObserver`:** library mutates during scan — invalidate stale clusters.
- **Limited Library Access:** users can grant access to a subset. Support it gracefully, but communicate honestly that full access enables full cleanup.
- **Byte size estimation:** `PHAssetResource.fileSize` is expensive. Sample, don't iterate everything.
- **MetricKit:** Apple-native diagnostics. NEVER add Sentry, Firebase, Crashlytics, or any third-party SDK that touches user data — this violates the privacy promise.
