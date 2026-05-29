# App Store screenshots — v1.1

> Six screenshots showcasing the v1.1 module set. Apple requires 6.7" iPhone (iPhone 17 Pro / Plus class) at minimum; an iPad set is optional. This document defines composition + overlay text so the actual captures and the Figma export both stay consistent.

## Device & dimensions

- **Primary:** iPhone 17 Pro display, 6.9" (1320 × 2868 px).
- **Status bar:** generic 9:41 / Wi-Fi 4 bars / battery 100%. Capture in the simulator with `xcrun simctl status_bar override` to lock these.
- **Color scheme:** Light Mode for shots 1, 2, 4, 5, 6 — Dark Mode for shot 3 (proves the asset catalog work).
- **Locale:** en-US.

## Visual style for overlay text

- **Font:** SF Pro Display, weight 700, leading 1.05.
- **Color:** `#1F2A1F` on light shots, `#ECE7D8` on dark.
- **Background:** subtle radial-gradient sash behind the screen mockup using `BidePrimary` (light) / `BidePrimary` dark variant (dark).
- **Composition:** mockup centered on lower 65%, text headline + sub-headline stacked on top 30%.

## Shot 1 — Dashboard (cover)

**Headline:** Calm photo declutter for iPhone.
**Sub:** Eight modules. Nothing leaves your phone. Nothing deletes without you.

**Composition:**
- Bide Dashboard with all 8 module cards visible.
- "On This Day" callout present with "3 photos, starting 4 years ago".
- Review Basket bar empty (not shown).
- Freshness pill at bottom reading "Updated just now".

**Setup steps:**
1. Sim → Bide → grant full access.
2. Pull to refresh; wait for `lastRefreshAt` to populate.
3. Status-bar override.
4. Screenshot via `xcrun simctl io booted screenshot`.

## Shot 2 — Exact Duplicates result

**Headline:** Catch the duplicates Apple misses.
**Sub:** Byte-for-byte, including imports and re-saves. Seconds, not minutes.

**Composition:**
- `ExactDuplicatesView` showing 3 groups, one expanded with 4 thumbnails.
- Header shows "5 groups · 187 MB reclaimable".
- Reclaim CTA at bottom visible but not pressed.

**Setup:** seed test library with 4 copies of three photos. Open module.

## Shot 3 — Live Photos with Convert button (DARK MODE)

**Headline:** Keep the photo. Drop the sidecar.
**Sub:** Convert any Live Photo to a still and reclaim about 40% of its size.

**Composition:**
- `LivePhotosView` in dark mode showing 3 rows.
- Top row has "Convert to still photo" button highlighted (tap-target visible).
- Per-row "Video sidecar: 1.8 MB" text visible.
- Header reads "127 MB · 16 Live Photos".

**Setup:** Simulator must be in dark mode (`Settings → Developer → Dark Appearance` or `xcrun simctl ui booted appearance dark`).

## Shot 4 — Similar Photos cluster review

**Headline:** Suggestions you can trust.
**Sub:** Bide picks a keeper and tells you why. You decide.

**Composition:**
- `ClusterReviewView` showing one cluster of 4 photos.
- Suggested keeper has the green badge with "Suggested because it's been edited."
- One non-keeper photo is selected (blue checkmark).
- "Add 1 to Review Basket" CTA visible at bottom.

**Setup:** Simulator with a known burst of 4 from June 2023. Edit one.

## Shot 5 — Session Summary

**Headline:** Every removal is reversible.
**Sub:** Items go to Apple's Recently Deleted. 30 days to change your mind.

**Composition:**
- `SessionSummaryView` post-deletion.
- Big "1.8 GB" number.
- "12 items moved to Recently Deleted".
- "30 days to change your mind" card visible with the icon.
- Lifetime blurb: "Lifetime with Bide: 4.6 GB across 6 sessions".

**Setup:** Use TestFlight-style synthetic deletion. Or modify `SessionSummaryView` preview block to produce the screen, capture from Xcode preview at 1320×2868.

## Shot 6 — Settings with Lifetime + Help

**Headline:** Your number. Always yours.
**Sub:** Bide tracks what you've reclaimed locally — and nothing else.

**Composition:**
- `SettingsView` open.
- Lifetime row at top: "4.6 GB · Reclaimed across 6 sessions · 412 items".
- Privacy section visible with 4 checkmarks.
- "How Bide works" row in the Help section visible.
- "Share Bide with a friend" row in "Spread the calm" visible.

**Setup:** Simulator with seeded `ReclaimSession` rows so the lifetime block has real numbers. Status-bar override.

## Capture commands

```bash
# Boot the sim once
xcrun simctl boot "iPhone 17 Pro"

# Status bar lock
xcrun simctl status_bar booted override \
  --time "9:41" \
  --dataNetwork wifi --wifiBars 4 --cellularBars 4 \
  --batteryState charged --batteryLevel 100

# Dark mode for shot 3
xcrun simctl ui booted appearance dark
# Light for the others
xcrun simctl ui booted appearance light

# Screenshot to file
xcrun simctl io booted screenshot ~/Desktop/bide-shot-1.png
```

## Export pipeline

1. Capture raw screenshots from the simulator.
2. Open `marketing/screenshots.fig` (Figma template, not yet created — see ROADMAP infra section).
3. Paste each capture into its layer; the layer applies the headline overlay + gradient sash.
4. Export at 1320 × 2868 PNG via Figma.
5. Upload via App Store Connect → Bide → 1.1 → Media Manager, or via the App Store Connect API (`POST /v1/appScreenshots`).

## Acceptance

- All six shots taken at exactly 1320 × 2868.
- Status bar locked identical across all shots.
- Each shot's overlay text is in the headline font + size defined above.
- One Dark Mode shot.
- No iCloud "needs download" placeholders visible (all thumbnails loaded).
- No personally identifiable photos in any frame.

---

## v1.2 captured chrome (assets/screenshots-v1.2/)

Real simulator captures of the screens that do not require photo-library
content, taken via the `ScreenshotCaptureTests` XCUITest with the
status bar overridden to 9:41 / full signal:

- `01-dashboard.png` — dashboard with section grouping, module cards, Beta badges (shows the honest "Photo access needed" banner since the sim has no granted authorization)
- `02-settings.png` — privacy promises, permissions, Help, Transparency, Spread the calm
- `03-how-bide-works.png` — the in-app explainer

**Still needed for the App Store marketing set** (the six shots specced
above): a simulator (or device) with a seeded, authorized photo library
so the modules show real cluster/duplicate/large-video content, plus the
Figma overlay-text pipeline. Those are a design pass, not a code task —
the captures here prove the chrome renders correctly and give a starting
point.

To refresh these captures:

```bash
xcodebuild test -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BideUITests/ScreenshotCaptureTests \
  -resultBundlePath /tmp/bide-shots.xcresult
xcrun xcresulttool export attachments --path /tmp/bide-shots.xcresult \
  --output-path /tmp/bide-attachments
# then copy the named PNGs from the manifest into assets/screenshots-v1.2/
```
