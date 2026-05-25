# KeepKind iOS — Master Plan

> **Last updated:** 2026-05-25
> **Status:** Phase 0 — Setup (in progress)
> **Today's target:** App fully built with Large Videos + Screenshots modules, polished, submitted to App Store for review. Live in store within ~1 week (Apple review controls the final gate).

---

## Quick navigation

- [Product](#product)
- [Brand family](#brand-family-kind-apps)
- [Tech stack](#tech-stack)
- [Infrastructure](#infrastructure-mirrors-bluebook-stack-adapted-for-ios)
- [Architecture](#architecture)
- [Modules — build order](#modules--build-order)
- [Phased delivery](#phased-delivery)
- [Skills to build](#skills-to-build-under-claudeskills)
- [Open decisions](#open-decisions)
- [Risks](#risks-and-mitigations)
- [Quality bar](#quality-bar)
- [Documentation index](#documentation-index)

---

## Product

**KeepKind: Photo Declutter** — a private, on-device photo review app that helps people safely reclaim their camera roll without losing memories.

- **Promise:** Keep the memories. Clear the clutter.
- **App Store subtitle:** Safe camera roll cleanup
- **Differentiator:** *The photo cleaner for people who don't trust photo cleaners.*

Full product specification: [product/spec.md](./product/spec.md)

## Brand family: Kind Apps

Simple public-good iOS apps with no ads, no accounts, no tracking SDKs.

- **PageKind** — private scanner (built separately)
- **KeepKind** — this app

Brand pledge:
- Free
- No ads
- No subscriptions
- No account
- No tracking SDKs
- No photo upload by us
- No automatic mass deletion
- No fake danger warnings
- No dark-pattern paywall

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| Language | Swift 5.10 | Native iOS |
| UI | SwiftUI | Modern, declarative; faster to ship beautiful UI |
| Target | iOS 17+ | Covers ~90% of active devices; gives us SwiftData and latest PhotoKit |
| Photo access | PhotoKit | `PHPhotoLibrary`, `PHAsset`, `PHAssetChangeRequest` |
| Image analysis | Vision | `VNGenerateImageFeaturePrintRequest` for similarity |
| Persistence | SwiftData | Local-only index, no server |
| Background work | BackgroundTasks | Light scan continuation |
| Diagnostics | MetricKit | Apple-native, zero third-party tracking |
| Testing | XCTest + XCUITest | Native test stack |
| Linting | SwiftLint + swift-format | Standard Swift toolchain |
| Beta dist | TestFlight | Apple-native |
| Production dist | App Store | Apple-native |

## Infrastructure (mirrors BlueBook stack, adapted for iOS)

| Concern | Service | Detail |
|---|---|---|
| Source | GitHub | `github.com/grifjef/keepkind-ios` (public) |
| CI/CD | GitHub Actions | `macos-latest` runners; `xcodebuild`, SwiftLint, tests, SonarCloud |
| Code quality | SonarCloud | `grifjef_keepkind-ios` project, Swift analyzer |
| Security review | Claude `/security-review` | Run on PRs via workflow |
| Dependencies | Dependabot | Swift Package Manager ecosystem |
| Issue tracking | Jira | `KK` project at `grifjef.atlassian.net` |
| Documentation | Confluence | `KK` space at `grifjef-1773158363073.atlassian.net/wiki` |
| Crash reporting | MetricKit | Apple-only — no Sentry/Firebase/Crashlytics |
| Privacy policy | GitHub Pages | hosted at repo's `gh-pages` until `keepkind.app` domain set up |

## Architecture

### Layers
- **UI:** SwiftUI views, MVVM with `@Observable` view models
- **Domain:** value types — `Asset`, `Cluster`, `ReviewDecision`, `Session`
- **Persistence:** SwiftData local index (schema in [docs/architecture.md](./docs/architecture.md))
- **PhotoKit adapter:** isolated layer wrapping `PHPhotoLibrary` calls
- **Vision adapter:** isolated layer for feature print + blur detection

### Processing stages (per spec §12)
1. **Lightweight library scan** — metadata only (IDs, types, dates, dimensions, durations, subtypes, favorites, hidden, rough size)
2. **High-impact candidates** — large videos, screenshots, screen recordings, bursts, exact metadata duplicates
3. **Visual similarity** — feature prints generated and compared *within time/burst/location buckets only* (avoids O(n²) blowup on large libraries)
4. **Quality scoring** — blur, exposure, faces (later)
5. **Recommendation generation** — conservative, explainable, review-first

### Safety model
Three-tier risk model (low / medium / high). Protected by default:
- Favorites
- Hidden photos
- Photos < 30 days old
- Edited photos
- Live Photos
- Photos with faces (unless in tight cluster)
- Photos in named albums
- One-of-one photos from a date/location
- Screenshots that contain confirmation codes / tickets / receipts (until user reviews)

Full detail: [docs/safety-model.md](./docs/safety-model.md) (to be written).

### Privacy architecture
- No backend
- No account
- No photo upload by us
- No third-party analytics SDKs
- No ad SDKs
- No App Tracking Transparency prompt (we don't track)
- Local-only SwiftData index
- Optional Apple-only diagnostics (MetricKit)
- Limited Library Access supported but full access recommended (with honest copy)

## Modules — build order

| # | Module | Phase | Risk | Why this order |
|---|---|---|---|---|
| 1 | Large Videos | 1 | Low | Biggest single payoff, zero AI needed, low false-positive risk |
| 2 | Screenshots | 1 | Low | Common clutter, simple grouping by date / source |
| 3 | Review Basket | 1 | — | Cross-cutting safety mechanism; nothing deletes without it |
| 4 | Similar Photos | 2 | High | The hard part; false positives destroy trust — weeks not hours |
| 5 | Blurry Shots | 2 | Medium | Optional, never auto-suggested, conservative thresholds |

## Phased delivery

### Phase 0 — Setup (today, 1–2 hrs) — **in progress**
- Verify name availability (App Store, USPTO, domains)
- Create GitHub repo `grifjef/keepkind-ios`
- Create Jira project `KK` + epics from spec
- Create Confluence space `KK` + skeleton pages
- Create SonarCloud Swift project, wire `SONAR_TOKEN`
- Confirm Apple Developer enrollment status (or start enrollment in parallel)

### Phase 1 — Core build (today, 3–5 hrs)
- Xcode project scaffold (SwiftUI, iOS 17+)
- SwiftLint + GitHub Actions CI (`macos-latest`)
- App shell: onboarding → dashboard → module → Review Basket → confirm → done
- PhotoKit permission flow with honest, clear copy
- SwiftData local index per spec §12 schema
- **Large Videos module end-to-end** — scan → sort by size → review cards → batch select → Review Basket → `PHAssetChangeRequest.deleteAssets`
- **Screenshots module** — group by month/year, bulk-selectable, OCR-bucket later
- MetricKit diagnostics wired
- Running in Simulator + sideloaded on your iPhone

### Phase 2 — TestFlight + App Store submission (today / tomorrow)
- App icon (1024×1024 source, all variant sizes)
- Privacy policy page (hosted on GitHub Pages until `keepkind.app` is purchased)
- App Store Connect listing — name, subtitle, description, keywords, screenshots
- Privacy questionnaire (PhotoKit access disclosure, no third-party tracking)
- Archive + upload via Xcode
- TestFlight build available to you + friend (internal testers)
- Submit for App Store review

### Phase 3 — Similar Photos engine (this week)
- Vision feature print generation per asset
- Time-bucket clustering (same day, hour, burst, location radius)
- Cluster review UI (recommended keeper + comparison strip + score indicators)
- "Suggested keeper" not "Best photo" — earns trust through humility
- Conservative thresholds, protected categories enforced
- Performance: cap visual comparison to within-bucket only

### Phase 4 — Polish + Blurry Shots (this week)
- Blurry candidate module
- Accessibility audit — VoiceOver, Dynamic Type, contrast
- Performance test on 10k / 50k libraries
- Edge cases: iCloud-only assets, limited library access, scan interruption, backgrounding, low battery

### Phase 5 — App Store live (1–7 days after submission)
- Apple review window (out of our control)
- Respond to any reviewer feedback within hours
- On approval: release

## Skills to build under `.claude/skills/`

| Skill | Purpose |
|---|---|
| `ios-build` | `xcodebuild` shortcuts (build, test, archive, export-ipa) |
| `apple-deploy` | TestFlight upload via `xcrun altool` or fastlane lane |
| `sonarcloud-swift` | Swift sonar config + `xccov-to-sonarqube-generic` coverage conversion |
| `photokit-snippets` | Auth, fetch, delete, change observer recipes |
| `jira-flow` | Create/transition issues against `grifjef.atlassian.net` via REST API |
| `confluence-doc` | Create/update wiki pages via Confluence REST API |

Built using `anthropic-skills:skill-creator`.

## Open decisions

1. **Apple Developer enrollment status** — checking now via developer.apple.com
2. **Name availability** — verifying KeepKind across App Store, USPTO, domains
3. **App icon source** — designed in SwiftUI? Hire designer? SF Symbols-based placeholder for first TestFlight?
4. **Privacy policy hosting** — GitHub Pages on repo until `keepkind.app` domain bought
5. **Brand color palette** — proposed: warm off-white background, muted sage green primary, dark teal accent. Confirm before icon design.
6. **iOS version floor** — recommending iOS 17+. Confirm OK to drop iOS 16.

## Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Apple Developer enrollment not active | Unknown until checked | Start enrollment today in parallel; sideload via free provisioning meanwhile |
| App Store review delay / rejection | Medium (cleaner-app category gets extra scrutiny) | Honest copy, no scare tactics, clear PhotoKit usage strings, pre-empt with privacy policy + review-first UX evidence in screenshots |
| Name trademark / App Store conflict | Unknown until checked | Verifying today; backups: PhotoKind, TidyRoll |
| False positives in similar-photo clustering | High in Phase 3 | Conservative thresholds, "Suggested keeper" framing, explanation strings, Review Basket safety net |
| iCloud-only assets break scan | Medium | `PHCachingImageManager` with `isNetworkAccessAllowed = false` for thumbnails; surface "needs download" state clearly |
| Performance death on 50k+ libraries | Medium | Stage processing, time-bucket before comparison, byte estimation by sampling |
| Apple rejects for "duplicate functionality" with built-in Duplicates | Low | We do screenshots, large videos, near-duplicates, blurry — strictly broader |
| Permission friction (user grants limited library) | Medium | Honest "limited mode" support; explain that full access enables full cleanup |

## Quality bar

From spec §20 — non-negotiable:

- Handles 10k / 50k asset libraries without crashing or pegging the CPU
- Never auto-deletes
- Explains every recommendation in plain language
- Respects favorites / hidden / recent / album-tagged by default
- Never uses scare or urgency language
- Moves items to Recently Deleted, never says "Delete forever"
- VoiceOver-accessible and Dynamic-Type-clean from v1
- Crash rate < 0.1% (measured via MetricKit / App Store Connect)
- Cold start < 2s on iPhone 12 and newer

## Development process

Mirrors BlueBook workflow:

1. **Plan** — Create Jira item under the right Epic. Status `Dev In Progress` when started.
2. **Branch** — `feature/KK-<id>-short-description`
3. **Implement + Test** — Code + XCTest tests. All checks must pass: SwiftLint, build, tests, SonarCloud.
4. **Document** — Update Confluence pages. Update `CLAUDE.md` if architecture / commands / patterns changed.
5. **PR** — Pushes trigger CI. Claude `/security-review` runs on PR. Merges trigger Apple-Cloud builds (later, when fastlane is set up).
6. **Complete** — Transition Jira to `Done`.

## Documentation index

- [`PLAN.md`](./PLAN.md) — this file (master plan)
- [`product/spec.md`](./product/spec.md) — full product specification (source of truth for product decisions)
- `docs/architecture.md` — technical architecture and SwiftData schema (to be written)
- `docs/safety-model.md` — risk tiers, protected categories (to be written)
- `docs/photokit-usage.md` — permissions, fetching, deletion, change observers (to be written)
- `docs/similar-photo-algorithm.md` — feature print + clustering (to be written)
- `docs/privacy-policy.md` — final copy for hosting (to be written)
- `docs/app-store-listing.md` — final listing copy (to be written)
- `docs/decisions.md` — decision log with rationale (to be written)
- `CLAUDE.md` — project context for future Claude Code sessions (to be written)
