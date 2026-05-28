# Safety model

> The promise: nothing gets deleted by accident. This document lists every signal Bide uses to decide what to protect, in which module, and at what point in the flow.

The safety contract has three layers, each backed by code rather than copy:

1. **Pre-flight filtering** — assets that match a protected signal are never scanned or never surfaced as candidates.
2. **Per-item protection at display** — even surfaced candidates are visually marked as protected and disabled if a signal applies.
3. **Review Basket confirmation** — nothing leaves the user's library until they tap "Move to Recently Deleted", which itself triggers iOS's system confirmation sheet on top.

Even then, deletion lands in Recently Deleted (Apple's 30-day recovery window) — never `PHAssetEditOperation.delete` with the permanent variant.

---

## Protected signals (by module)

A `✓` means "items matching this signal are auto-protected in this module" — they are not selectable for deletion without an explicit override (which we don't expose today).

| Signal | Large Videos | Screenshots | Similar Photos | Blurry Shots |
|---|:---:|:---:|:---:|:---:|
| `isFavorite` | ✓ display-only | ✓ display + skip from selectable | ✓ implicit keeper | ✓ pre-flight skip |
| `isHidden` | ✓ display-only | ✓ display + skip from selectable | implicit (we don't fetch hidden) | ✓ pre-flight skip |
| `creationDate` < 30d ago | — | ✓ display + skip from selectable | — | ✓ pre-flight skip |
| Edited (`modificationDate > creationDate`) | — | — | preference in keeper scoring | — |
| `isLivePhoto` | — | — | preference in keeper scoring | — |
| In a user album (`isInUserAlbum`) | — | — | preference in keeper scoring | — |
| Sole photo from its date+location | — | — | future (v0.3) | future (v0.3) |
| Contains a face | — | — | future (v0.3) | future (v0.3) |
| Contains a QR/code/receipt (OCR) | — | future (v1.5) | — | — |

### Module-specific notes

**Large Videos** (`LargeVideosView`):
- Favorites and hidden videos appear in the list with a "Protected" badge and the tap-to-toggle button is disabled. They count toward the "X videos using Y GB" total but cannot be added to the basket.

**Screenshots** (`ScreenshotsView` + `ScreenshotsViewModel.protectionReason`):
- Three reasons are computed per item: `.favorite`, `.hidden`, `.recent`. Favorite takes precedence over recent.
- The month section's "Select all" button only operates on the `selectableItems` subset (protected items are skipped entirely).
- Recency threshold is configurable (default 30 days) and `now` is injectable, so tests exercise the boundary directly.

**Similar Photos** (`SimilarityClusterer.pickKeeper`):
- We use the protected signals as *preference* in the keeper-selection scoring, not as *exclusion* from the cluster. A cluster of 4 photos where one is a favorite always has that favorite as the suggested keeper.
- Hidden assets never enter the candidate pool because `fetchPhotoCandidates` predicates `mediaType == image` against PhotoKit's standard "smart" album, which excludes hidden by default.
- A cluster member can still be added to the basket by the user, *unless* it is `isFavorite || isHidden` — `ClusterReviewView`'s `CandidateRow.disabled` enforces this.

**Blurry Shots** (`BlurryShotsScanService.isProtected`):
- The most conservative module. Favorites, hidden, and last-30-days are skipped before we even bother to compute a blur score. This saves work *and* makes the surfaced list pre-filtered.
- The number skipped is shown in the summary header ("X protected and skipped") so the user knows we're not silently flagging their recent shots.

---

## Recency rule

`creationDate` within the last 30 days is protected in any module that uses it. The threshold is one configurable constant in two places (`ScreenshotsViewModel.recencyThreshold` and `BlurryShotsScanService.recencyThreshold`) — both default to 30 days.

Rationale (per spec §14): users often clear screenshots / blurry shots from their pre-30-day backlog but might still need a recent one for something active (receipt verification, sharing). We err on the side of keeping the recent one.

---

## Deletion mechanics

Every module feeds into a single `ReviewBasket`. The basket persists in memory for the session and shows the count + estimated reclaimable bytes at the bottom of the dashboard.

Tap "Review basket" → `ReviewBasketView`:

1. The user sees every item they've added, grouped by `ReviewBasket.Source` — Large videos, Screen recordings, Screenshots, Live Photos, Similar photos, Blurry shots, Exact duplicates, On this day. Each module writes to its own source enum case so the basket groups items accurately by where they came from.
2. Any item can be removed from the basket with a minus-circle button.
3. The "Cancel basket" link clears everything and dismisses.
4. The primary action is "Move to Recently Deleted" — this is what we call it everywhere. Never "Delete forever".
5. Tapping it shows our confirmation alert (with explicit 30-day recovery explanation), and on confirm, iOS shows its own system sheet asking the user to authorize the deletion.
6. Only then does `PHAssetChangeRequest.deleteAssets` fire.

**If the user cancels the iOS sheet**, our error path detects `PHPhotosErrorDomain code 3072` and shows "Nothing was deleted" — no scary error, no lost basket state.

---

## Defaults we are deliberately NOT changing

These are choices, listed here so future contributors don't soften them by accident.

- **No "Skip warnings" / "Trust me" toggle.** Even if a user wants to remove their own favorites, they have to do it from Photos.
- **No long-press / swipe-to-delete shortcuts.** Every removal goes through the basket.
- **No undo within Bide.** Recently Deleted is the undo. We tell the user that, repeatedly.
- **No "Delete duplicates automatically" mode.** This is the entire wedge — we are not a one-tap cleaner.
- **No "Empty Recently Deleted" affordance.** That's Photos.app's job. We never reach into the 30-day recovery window.

If a future PR adds any of these, the diff is wrong.

---

## Risk levels (from spec §14)

The product spec defines low/medium/high risk categories that don't all have code today. As we add modules, we'll fill these in.

| Risk | Examples | Status |
|---|---|---|
| **Low** | Old screenshots, screen recordings > 1GB, exact duplicates, blurry accidental shots with no faces | Large Videos (size sort), Screenshots (date/non-recent), Blurry Shots covers most |
| **Medium** | Similar photos, memes, receipts, downloaded images | Similar Photos covers the first; meme/receipt OCR is v1.5 |
| **High** | Faces, favorites, hidden, in-album, around major dates, Live Photos, edited, location-tagged | Partial — favorites/hidden/album/edited/Live are signals; faces, major-date, location-tagged are v0.3+ |

When in doubt, we default to "high risk" and skip auto-suggesting.
