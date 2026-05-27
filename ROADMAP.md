# Bide roadmap

> **Last updated:** 2026-05-27
> **Live status:** v0.1 (build 1) submitted to Apple, **Waiting for Review**.

This is the prioritized backlog after the v0.1 submission. Items are grouped by the version they'll ship in, then by priority within each version.

---

## v0.1.x — Apple review iteration

These ship if Apple kicks back the v0.1 submission with feedback.

- **Respond to Apple Review feedback** — within hours of receipt
- **Resubmit** with any required tweaks

If approval is clean: nothing here. Skip to v0.2.

---

## v0.2 — The real product (this week)

v0.1 has the architecture. v0.2 is what makes Bide actually differentiated from every "AI cleaner" in the App Store.

### P0 — Screenshots module (replace placeholder)

The current Screenshots view is a "coming soon" placeholder. Real implementation:

- Fetch screenshots via `PHAssetMediaSubtype.photoScreenshot` (already in `PhotoLibraryService.fetchScreenshots`)
- Group by month/year (LazyVStack with section headers)
- Multi-select with a top-bar count + "Add to Basket" action
- Protected defaults: favorited, hidden, last-30-days
- Tests: grouping logic, protection logic, basket round-trip

**Files to add/change:**
- `Bide/Modules/Screenshots/ScreenshotsView.swift` (rewrite, not placeholder)
- `Bide/Modules/Screenshots/ScreenshotsViewModel.swift` (new)
- `Bide/Modules/Screenshots/ScreenshotGrid.swift` (new — reusable selectable grid)
- `BideTests/ScreenshotsViewModelTests.swift`

### P0 — Similar Photos engine

The product spec's "core magic" (§8.3). Largest single feature in v0.2.

**Plan:**
1. `VisionService.swift` — wraps `VNGenerateImageFeaturePrintRequest`
2. `SimilarityClusterer.swift` — pure algorithm:
   - Bucket by time window (same day → same hour → same burst)
   - Within each bucket, compute pairwise feature print distance
   - Threshold-based agglomerative clustering
   - Return clusters sorted by representative date
3. `SimilarPhoto` model in SwiftData (extend `IndexedAsset` with `clusterIdentifier`, `featurePrintData`, `featurePrintVersion`)
4. `SimilarPhotosScanService.swift` — orchestrates: fetch → thumbnails → feature prints → cluster
5. UI:
   - `SimilarPhotosView.swift` — list of cluster cards
   - `ClusterReviewView.swift` — side-by-side comparison with "Suggested keeper" + reason
   - "Keep one" / "Keep all" / "Choose manually" buttons
6. Tests:
   - Time bucketing (boundary cases)
   - Clustering correctness on synthetic feature prints
   - Keeper selection scoring (favorite > edited > sharper > larger)

**Engineering principles:**
- Conservative thresholds — false positives kill trust more than missed clusters
- Always show explanation ("Suggested because it's sharper" / "favorited" / "edited")
- Never auto-select the rejected photos; user must explicitly add to basket
- Bucket-first so we never do O(n²) on the full library

### P1 — Blurry shots module (cautious)

After Similar Photos lands.

- Vision-based blur detection (Laplacian variance or Apple's built-in sharpness signal)
- "Maybe remove" framing, never "bad photos"
- Conservative threshold — favorites/hidden/recent always protected
- All candidates require manual review; no bulk action

### P1 — Performance hardening

- `PHPhotoLibraryChangeObserver` to invalidate stale clusters when library mutates mid-scan
- Sampling-based byte estimation (cap at 100 sampled assets per category)
- Stage processing: lightweight scan → high-impact candidates → visual similarity → quality scoring
- Test on a synthetic 50k-asset library (instrumentation test)

### P2 — iCloud Photos hardening

- Handle assets where local data isn't downloaded (`PHCachingImageManager` with `isNetworkAccessAllowed = false` by default)
- Surface "needs download" state in UI
- Don't silently trigger iCloud downloads during scan

---

## v0.3 — Trust polish

Items that don't unlock new functionality but tighten the trust contract.

- VoiceOver pass on every screen (audit + fix labels)
- Dynamic Type test at XL / XXL accessibility sizes
- Contrast audit (WCAG AA minimum)
- Localization scaffolding (don't translate yet, but extract strings)
- Crash reporting via MetricKit (already wired; verify it surfaces in Xcode Organizer)

---

## v1.0 — Public launch polish

- New 1024×1024 app icon (commissioned or rerendered — current is "good enough" SF Symbol)
- App Store screenshots redesigned with marketing copy overlays
- Marketing site at `bidephoto.com` (beyond the privacy policy)
- Launch posts: r/iosapps, r/iphone, r/privacy, parent Facebook groups
- TikTok/Reels demo videos

---

## Infrastructure backlog

Items that aren't features but reduce friction over time.

- [ ] **Buy `bidephoto.com`** + 3 defensive variants (~$48/yr, Cloudflare Registrar) — user action
- [ ] **Add `SONAR_TOKEN` to GitHub Secrets** — user action, once they create the SonarCloud project
- [ ] **Create SonarCloud project** under `grifjef` org — wired in CI but currently non-blocking
- [ ] **Configure Claude `/security-review` in CI workflow** — runs adversarial review on PRs
- [ ] **Branch protection** on `main` (require CI green)
- [ ] **Dependabot config audit** — verify weekly SPM + GHA updates fire
- [ ] **Add `LICENSE.md` reference to in-app Settings** — link from "Source on GitHub" to specific license

---

## Decision rules for the backlog

When deciding what to do next:

1. **Trust beats features.** A polish item that improves reviewer confidence beats a feature item that adds complexity.
2. **Performance + correctness beat polish.** A clustering bug that mis-suggests a deletion is worse than a missing module.
3. **Always reversible.** Deletion always lands in Recently Deleted. Never offer "delete permanently" — even if Apple's API supports it.
4. **No third-party SDKs.** Ever. The "no tracking" promise is on-disk verifiable in source.
5. **Conservative defaults stay conservative.** Favorites/hidden/recent are protected unless the user explicitly overrides — and even then, we ask twice.

---

## Cluster-review notes (engineering memo)

For the Similar Photos engine specifically — design notes that the code should preserve:

- **Feature print version is part of the index.** If we update the Vision model in iOS 27, we re-cluster from scratch rather than mixing versions.
- **Bucket boundaries are forgiving.** Two photos at 11:59:59 and 12:00:01 should be in the same hour bucket. Use a windowed approach, not strict floor.
- **Recommended keeper is a *suggestion*.** Copy says "Suggested keeper", never "Best photo". Tap a different photo to override; the basket only contains what the user explicitly added.
- **Show the reason.** "Suggested because it's sharper." / "favorited" / "edited" / "Live Photo" / "higher resolution". This is the trust mechanism.
- **Protected categories never auto-clustered.** If a photo is favorited or in an album, it's the implicit keeper of its cluster.
