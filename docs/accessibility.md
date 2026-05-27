# Accessibility

> "VoiceOver-clean from v1" is non-negotiable (product principle 7). This doc captures the conventions we apply across every view so the experience is consistent, plus what's audited and what's queued.

---

## Convention: selectable rows

Across every module, the same pattern handles selectable items (Large Videos, Screenshots, Similar Photos cluster candidates, Blurry Shots). Each row exposes:

| Attribute | Purpose | Source |
|---|---|---|
| `accessibilityLabel` | What the item is — never just the time, always includes the asset metadata most relevant to the decision (size, date, dimensions) and the protected-because reason if applicable | computed from the value type |
| `accessibilityValue` | Current state — "Selected for review basket" or "Not selected" | the `isSelected` flag |
| `accessibilityHint` | What happens on action — "Double-tap to add to Review Basket". Empty when the item is protected/disabled. | static |
| `.isSelected` trait | Standard iOS audio cue when selected | toggled from `isSelected` |

Implemented in:
- `LargeVideosView.VideoRow` (`Bide/Modules/LargeVideos/LargeVideosView.swift`)
- `ScreenshotsView.ScreenshotTile` (`Bide/Modules/Screenshots/ScreenshotsView.swift`)
- `ClusterReviewView.CandidateRow` (`Bide/Modules/SimilarPhotos/ClusterReviewView.swift`)
- `BlurryShotsView.BlurryRow` (`Bide/Modules/BlurryShots/BlurryShotsView.swift`)

---

## Convention: cluster cards / module entry points

For tappable rows that *open another view* (not toggle state):

- `accessibilityElement(children: .combine)` — collapse the multi-element label into a single rotor item
- `accessibilityLabel` — summarize the contents (count, date, reclaimable bytes, in-basket count if any)
- `accessibilityHint` — "Double-tap to review this cluster" / "Double-tap to open Large Videos"

Implemented in:
- `SimilarPhotosView.ClusterCard` (`Bide/Modules/SimilarPhotos/SimilarPhotosView.swift`)
- `Dashboard.ModuleCard` (`Bide/Dashboard/ModuleCard.swift`) — already had this pre-v0.3

---

## Convention: banners + announcement-style elements

For non-interactive informational elements:

- `accessibilityElement(children: .combine)` to fuse the multi-line content
- `accessibilityLabel` describes the situation + recommended action in one short sentence

Implemented in:
- `LimitedLibraryBanner` (`Bide/Dashboard/LimitedLibraryBanner.swift`)
- `DashboardView.permissionBanner` (inline)

---

## Convention: primary action buttons (delete, save, submit)

Buttons with consequence (especially the basket bar and the "Move to Recently Deleted" button) carry:

- A `accessibilityLabel` that **states the consequence**, not just the button text. E.g. the basket bar's label is "Open Review Basket. 3 items, 240 MB total." — VoiceOver users hear what's actually in the basket, not just the button label.
- An `accessibilityHint` that clarifies the next step. E.g. "Double-tap to review and confirm before moving items to Recently Deleted." — makes clear the next tap is *review*, not *destroy*.

Implemented in:
- `DashboardView.reviewBasketBar` (`Bide/Dashboard/DashboardView.swift`)
- `ReviewBasketView` bottom bar — uses standard SwiftUI Button so the system label suffices

---

## Auditing checklist

Before any v0.3 release, walk through this list with VoiceOver enabled on a physical device:

- [ ] **Onboarding**: each of 3 pages reads in order; "Continue" / "Give Bide photo access" announce clearly
- [ ] **Dashboard**: permission banner reads if visible; LimitedLibrary banner reads if visible; each module card reads with badge if any; Review Basket bar reads with current count + total
- [ ] **Large Videos**: list items read with size/duration/date; protected items announce protection reason; selected items announce selected state
- [ ] **Screenshots**: month headers read; tiles within each section read with date + selected state; protected tiles announce reason
- [ ] **Similar Photos**: cluster cards read with count + date + reclaim hint; cluster review screen reads suggested keeper + reason; candidates read with selected state
- [ ] **Blurry Shots**: candidates read with confidence label + date + size
- [ ] **Review Basket**: section headers read; rows read with size + date + remove-button label; primary action reads "Move to Recently Deleted" with the 30-day recovery message as a hint
- [ ] **Settings**: privacy promise reads each line; GitHub link announces destination

---

## Dynamic Type

All text uses `Font.system(.bodyStyle, design:, weight:)` via `BideTheme.body()` etc., which respects the system Dynamic Type setting automatically. The audit step before v0.3 release:

- [ ] Test the largest accessibility size (XXL Accessibility) on each module — text should wrap, not truncate
- [ ] Card heights should expand to accommodate larger text
- [ ] Two known places to watch:
  - Dashboard `ModuleCard` — currently uses `fixedSize(horizontal: false, vertical: true)` on the subtitle; verify at XXL
  - `BlurryRow` — the "score 142" mono text could overflow at XXL

If anything truncates, add `lineLimit(nil)` and `.fixedSize(horizontal: false, vertical: true)` to the offending Text.

---

## Contrast

`BideTheme` color tokens hit WCAG AA against the default background. Two pairs to keep an eye on if the palette evolves:

- `BideTheme.warning` on `BideTheme.surface` — currently a muted amber on tertiary-system-background. AA at body size, borderline at small caption size. If this ever feels light, darken `warning` rather than re-tinting the background.
- `BideTheme.textTertiary` (= `.tertiaryLabel`) — Apple's system token; AA-rated by Apple. Don't override.

---

## Items still queued for v0.3 / v1.0

- **VoiceOver rotor for clusters**: emit a `accessibilityRotor` "Clusters" so VoiceOver users can jump cluster-to-cluster without scrolling row-by-row
- **Dynamic Type physical-device pass**: simulator doesn't expose AX-only sizes well; do this on real hardware
- **Localization scaffolding**: extract all user-facing strings to `Localizable.strings` so future-language work doesn't need a separate refactor. Pseudo-loc test before localizing.
- **Reduce Motion**: audit the few `withAnimation` calls (RootView phase transitions, Continue→next-page in onboarding); offer no-animation alternatives when the OS reports `reduceMotion`
