---
layout: default
title: Bide Privacy Policy
permalink: /privacy/
---

**Last updated:** 2026-05-27
**App:** Bide (iOS) — `com.bidephoto.bide`
**Developer:** Jeff Griffith
**Contact:** grif.jef@gmail.com

---

## The short version

Bide runs entirely on your iPhone. We do not collect, transmit, store, or sell any of your data. We do not require an account. We do not include any third-party analytics or advertising SDKs.

If you ever feel that any of this is inaccurate, please email grif.jef@gmail.com — we'll investigate, fix it, and update this policy.

---

## What Bide does on your phone

Bide reads your photo library (with your permission) to find clutter — large videos, screenshots, similar photos, blurry shots — and offers you a calm interface to review and remove items you no longer want.

To do that, the app:

- Requests **read+write photo library access** through Apple's PhotoKit framework
- Reads metadata (creation date, dimensions, duration, file size, favorite/hidden flags, burst identifier) about each asset in the library
- Optionally generates **on-device Vision feature prints** (Apple's image-similarity hash) for similar-photo clustering — this is computed locally and stored only on your device
- Maintains a **local SwiftData index** so it doesn't have to re-scan from scratch every time you open the app
- Sends the items you mark for removal to **Apple's Recently Deleted album** via `PHAssetChangeRequest.deleteAssets` — items stay there for 30 days and can be recovered from Photos

That's it. None of this data leaves your iPhone via any channel that Bide controls.

## What Bide does NOT do

- We do not run a backend server. There is no Bide cloud.
- We do not upload your photos, thumbnails, metadata, or any derived data anywhere.
- We do not require an account or sign-in.
- We do not include third-party analytics SDKs (no Firebase, no Google Analytics, no Mixpanel, no Amplitude, no Segment, etc.).
- We do not include advertising SDKs or display ads.
- We do not collect or read any unique identifiers (no IDFA, no advertising ID, no user ID).
- We do not show the App Tracking Transparency prompt because we do not track.
- We do not collect crash reports through any third-party service.
- We do not sell, rent, share, or trade any data — we do not have any data to share.

## Diagnostics

iOS itself, through Apple's **MetricKit** framework, may collect anonymized crash and performance data and may share aggregate summaries with the developer of an app. This is an Apple-controlled, system-level feature — not something Bide implements.

If you do not want to share that data:
- iOS Settings → Privacy & Security → Analytics & Improvements → turn off **Share With App Developers**

Bide functions identically whether this is on or off. We have no way to identify you from any MetricKit data Apple may share.

## iCloud Photos and other Apple services

If you sync your photo library through iCloud Photos, **Apple's iCloud terms apply to that sync** — not this policy. Bide reads from and writes to the same photo library that iCloud syncs, but Bide itself does not interact with iCloud or any Apple server.

Deleting an item through Bide moves it to "Recently Deleted" in Photos. If iCloud Photos is enabled, that change syncs across your devices through Apple's infrastructure. Bide does not initiate or control that sync.

## Children's privacy

Bide is rated 4+ in the App Store. Bide does not collect any data from anyone, including children. This policy is therefore compliant with COPPA and similar children-privacy regulations by virtue of collecting nothing.

## Your rights

Because we collect no personal data, there is nothing for us to:

- Provide access to
- Correct
- Delete
- Restrict processing of
- Port

If you uninstall Bide, the local index it kept on your device is removed with the app, per standard iOS behavior. To clear the index without uninstalling:

- iOS Settings → General → iPhone Storage → Bide → Offload App (clears app data while keeping the app), then re-download

## Open source

Bide's source code is published at:

**https://github.com/grifjef/bide-ios**

You — or anyone — can read the code and verify that the above is accurate. If you find a discrepancy, please open an issue on GitHub.

## Changes to this policy

If we ever change anything Bide does that would affect what's described here, we will update this policy and bump the "Last updated" date at the top. Material changes (anything that would weaken any of the promises above) would also be flagged in the app's "What's New" release notes.

## Contact

**Email:** grif.jef@gmail.com
**Source:** https://github.com/grifjef/bide-ios

---

*This policy is written in plain English on purpose. If anything is unclear, please ask — we will rewrite the section to make it clearer.*
