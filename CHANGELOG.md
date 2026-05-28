# Changelog

All notable changes to Bide. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely, and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Detailed App Store "What's New" copy and internal change logs live under [`docs/release-notes/`](docs/release-notes/).

## [1.1.0] — In TestFlight prep

> Marketing version `1.1.0`, build `2`.
> Submitting once 1.0 is approved by App Store Review.

### Added

- Four new modules: **Screen Recordings**, **Live Photos** (with convert-to-still), **Exact Duplicates**, **On This Day**.
- **Live Photo → still conversion** preserves the photo and reclaims the video sidecar (~40%).
- **Stream-based scanning** handles 5k–50k assets per pass via `AsyncStream`.
- **Onboarding-time pre-scan** so the dashboard arrives populated.
- **Lifetime reclaim tracking** + **Recent sessions list** in Settings.
- **Limited Library Access** banner.
- **iCloud "needs download"** state in `ThumbnailView`.
- **Screenshot OCR categorization** (visual / mixed / text-heavy) with filter chips.
- **Dashboard section grouping** (Quick wins / Bulk review / Careful review).
- **MetricKit diagnostics** surfaced in Settings → Diagnostics with Share affordance.
- **Marketing landing page** at GitHub Pages.
- **Dashboard auto-refresh on library change** via `PhotoLibraryObserver` (debounced, dirty-flag mid-flight).
- **Recent-capture (<30d) soft badge** in Large Videos / Screen Recordings / Live Photos.
- **In-app "How Bide works"** explainer in Settings.
- **Dashboard freshness pill** ("Updated 2 min ago").
- **Share Bide** affordance personalized with the user's lifetime byte total.
- **OSLog signposts** on Dashboard refresh phases, Similar Photos scan, Exact Duplicates detect.
- **Color asset catalog** with light + dark variants for primary / accent / warning.
- **Reduce Motion** respected in root transition and onboarding page swap.
- **`PHCachingImageManager` prewarming** for the Screenshots grid.
- **`BGAppRefreshTask` background refresh** so the dashboard is current overnight.
- **"What's new" sheet** on first launch after upgrade.

### Changed

- `MARKETING_VERSION` 1.0 → 1.1.0, `CURRENT_PROJECT_VERSION` 1 → 2.
- Settings "Version" row reads from `Bundle.main` (no more hardcoded literal).
- `PhotoLibraryService` thumbnail path routes through a shared `PHCachingImageManager`.

### Tests

183 unit + 1 UI passing, up from 130 at v1.0 submission. New suites: `LivePhotoSummaryTests`, `RecencyRuleTests`, `ReviewBasketTests` additions, `RefreshCoalescerTests`, `BackgroundRefreshSchedulerTests`, `WhatsNewPlannerTests`.

### Known limitations

- App Store screenshots have not been refreshed for the new module set yet (spec ready in `docs/app-store-screenshots-v1.1.md`).
- Localization scaffolding deferred to 1.2.

## [1.0.0] — 2026-05-27 (in App Store review)

Initial submission. Four modules: Large Videos, Screenshots, Similar Photos, Blurry Shots. SwiftData-backed feature-print index, Review Basket, full VoiceOver pass, on-device only.
