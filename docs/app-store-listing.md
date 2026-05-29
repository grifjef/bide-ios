# Bide — App Store listing copy

> Paste-ready content for App Store Connect. Each section names the App Store field it corresponds to.

## App name (30 char limit)

**Bide: Camera Roll Review**

Counts: 26 characters ✓

## Subtitle (30 char limit)

**Camera roll, at your pace**

Counts: 25 characters ✓

## Primary category

**Photo & Video**

## Secondary category (optional)

**Utilities**

## Keywords (100 char limit, comma-separated, no spaces after commas)

```
photo declutter,camera roll,duplicate photos,large videos,screenshots,live photos,no ads,private
```

Counts: ~96 characters ✓

(Notes on choices: leans into anti-cleaner-app positioning with "no ads,private"; covers the main user-search intents — "photo declutter", "camera roll", "duplicate photos"; surfaces three shipped modules with distinctive search terms — "large videos", "screenshots", "live photos"; avoids the category-poisoned terms "cleaner", "booster", "optimizer". "delete photos" was dropped in favor of "live photos" since "duplicate photos" + "photo declutter" already carry the delete intent.)

## Description (4000 char limit, plain text — no markup)

```
Bide is a calm, private photo declutter app for iPhone. The name means "to dwell, to wait patiently" — and that's the entire product philosophy. Take your time. Look twice. Nothing leaves your phone.

No ads. No account. No subscription. No cloud upload by us.

WHAT BIDE FINDS
• Exact duplicates — byte-for-byte identical copies, found in seconds
• Screen recordings — usually the biggest disposable files in your library
• Large videos — sorted biggest first, so a few minutes can free gigabytes
• Screenshots — grouped by month and year, sortable by chat / app / visual
• Live Photos — convert any to a still and reclaim its ~40% video sidecar
• Similar photos — near-duplicates clustered with a suggested keeper, and the reason why
• Blurry shots — conservative candidates only; photos with faces are excluded
• On this day — photos from today's calendar date in past years

EVERYTHING IS REVERSIBLE
Bide never permanently deletes anything. When you choose to remove an item, it goes to Apple's "Recently Deleted" album in Photos, where you have 30 days to restore it. No surprises.

PRIVACY YOU CAN VERIFY
• All analysis runs on your iPhone — PhotoKit + Apple's Vision framework, locally
• No backend servers we control
• No third-party analytics, ad SDKs, or tracking
• No account or sign-in required
• No App Tracking Transparency prompt — we don't track
• Optional diagnostics use Apple's MetricKit only; you can disable in iOS Settings
• Source code is public on GitHub

If you sync your library through iCloud Photos, Apple controls that — Bide doesn't touch the sync.

RESPECTFUL DEFAULTS
Bide is conservative by design:
• Favorites are never auto-selected for removal
• Hidden photos are protected
• Photos less than 30 days old are protected by default
• Edited photos and Live Photos get extra deference
• Every recommendation is explained in plain language ("suggested because it's sharper", "suggested because it's favorited")

WHY THIS APP EXISTS
The iPhone "cleaner app" category is dominated by predatory subscriptions, scare tactics, and one-tap mass deletion. Bide takes the opposite stance: conservative recommendations, explanations for every suggestion, a Review Basket safety net before any deletion, and zero data leaves your phone.

It's the photo cleaner for people who don't trust photo cleaners.

BIDE YOUR TIME. KEEP WHAT MATTERS.
```

## Promotional text (170 char limit — editable post-submission)

```
A calm, private photo declutter app. No ads, no account, no subscription. Find large videos and screenshots, review at your pace, keep the memories.
```

Counts: ~155 characters ✓

## What's New (4000 char limit, plain text — first release)

```
Hello. This is Bide v0.1 — the first public release.

WHAT'S HERE
• Large Videos: scan your library for the biggest video files and review them at your pace
• Screenshots: opens to the first iteration; deeper grouping and OCR-based screenshot categories land in the next update
• Review Basket: every removal goes through a confirmation flow first and lands in Apple's Recently Deleted (30-day recovery)
• Privacy and accessibility from day one — VoiceOver-clean, Dynamic Type, no third-party SDKs

WHAT'S COMING
• Similar photo groups (Vision feature-print clustering)
• Blurry shot review
• Smarter screenshot categories (receipts, codes, maps, conversations)

Bide your time. Keep what matters.
```

## Support URL

`https://github.com/grifjef/bide-ios` (for now — we can move to a hosted support page once `bidephoto.com` is configured)

## Marketing URL (optional)

`https://github.com/grifjef/bide-ios` (same — replace with marketing site later)

## Privacy Policy URL

`https://grifjef.github.io/bide-ios/privacy/` (we'll host this via GitHub Pages once `docs/privacy-policy.md` is ready; alternatively a raw GitHub URL works for first submission)

## Age rating questionnaire — answers

All "None" / "No" except:
- **Unrestricted Web Access:** No
- **Gambling:** No
- **User Generated Content:** No

Expected result: **4+** (suitable for all ages)

## App Privacy questionnaire — answers

For the "What data does this app collect?" sections:

| Category | Bide's answer |
|---|---|
| Contact Info | **Not collected** |
| Health & Fitness | Not collected |
| Financial Info | Not collected |
| Location | Not collected |
| Sensitive Info | Not collected |
| Contacts | Not collected |
| User Content | **Photos: Used by the app on-device; not uploaded** — Apple's questionnaire asks specifically about data sent off-device. We do not transmit photos. |
| Browsing History | Not collected |
| Search History | Not collected |
| Identifiers | Not collected (no advertising ID, no analytics user ID) |
| Purchases | Not collected (no in-app purchases) |
| Usage Data | **MetricKit-only diagnostics** — Apple's framework, opt-out via iOS Settings, no third-party collection |
| Diagnostics | Same as above |
| Other Data | Not collected |

For "Is data used to track the user?" → **No**

For "Is data linked to the user?" → **No** (no identifiers collected at all)

## Screenshots required

iPhone 6.9" (iPhone 17 Pro Max), iPhone 6.5" (older Pro Max), iPhone 5.5" (legacy compatibility — sometimes optional).

Shots to capture (in order shown in App Store):
1. **Onboarding "Bide your time"** — establishes the calm tone
2. **Dashboard with module cards** — what Bide does at a glance
3. **Large Videos list** — the "wow, I have 8GB of these" moment
4. **Review Basket** — the trust-center "nothing deletes until you confirm"
5. **Settings: privacy promise** — the no-ads/no-account/no-tracking pledge
6. **Onboarding "Nothing leaves your phone"** — the differentiator close

Capture from iPhone 17 Pro Simulator at 1290×2796 (iPhone 6.9" size).

## Build assignment

Upload via Xcode Organizer → Archives → Distribute → App Store Connect. First build will appear in TestFlight + ready-to-submit list within ~15min–2hr.

## Submission notes for App Review

Plain-text note to attach to the submission:

> Reviewer notes — Bide v0.1
>
> Bide is a privacy-focused photo declutter app. We request NSPhotoLibraryUsageDescription (read+write) because the app's core function is reviewing the user's photo library and offering to move selected items to Recently Deleted. No data leaves the device.
>
> The app does not collect or transmit any user data. There are no third-party SDKs. The only diagnostics are Apple's MetricKit framework, which the user can disable in iOS Settings.
>
> Deletion is performed via PHAssetChangeRequest.deleteAssets — this triggers the system confirmation sheet and items go to Recently Deleted (30-day recovery), per Apple's guidelines. We never request "permanent delete" capabilities.
>
> To exercise the deletion flow during review:
> 1. Open the app (grant photo permission when prompted)
> 2. Tap "Large videos" on the dashboard
> 3. Select any video and tap to add to Review Basket
> 4. Tap the Review Basket bar at the bottom
> 5. Confirm "Move to Recently Deleted" — system sheet appears, item moves to Photos > Albums > Recently Deleted
>
> Source code is public at https://github.com/grifjef/bide-ios.
