# Decisions log

> Running log of significant decisions and their rationale. Newest at top.

---

## 2026-05-25 — Name verification: KeepKind cleared

**Decision:** Commit to **KeepKind: Photo Declutter**.

**Verification performed:**

| Check | Method | Result |
|---|---|---|
| App Store name | iTunes Search API (`itunes.apple.com/search?term=KeepKind&entity=software`) | ✅ 17 results returned, **none named exactly "KeepKind"** (similar: Keepy, KeePass, Keepd, KeepBest, Keepyear, KeepMyVows, Keeply, Keeplinks, KeepStory). Name is available for App Store Connect. |
| `keepkind.com` | whois | ❌ **Taken.** Registered 2012-07-27 via Alibaba Cloud Computing (Beijing). Renewed through 2026-07-27. Likely speculative holder. |
| `keepkind.co` | whois | ❌ **Taken.** Registered 2022-05-10 via Key-Systems GmbH. |
| `keepkind.app` | DNS dig + rdap.org HTTP 404 | ✅ **Available.** No NS/A records; RDAP returns 404. |
| `kindapps.app` (brand family) | DNS dig + rdap.org | ✅ **Available.** |
| `kindapps.com` | whois | ❌ Taken (2013, godaddy). Not blocking — we use `.app` as primary. |
| `getkeepkind.com` | whois | ✅ Available (No match). |
| `keepkindapp.com` | whois | ✅ Available (No match). |
| USPTO trademark | Google + WebSearch for "KEEPKIND" + USPTO/Justia | ✅ No registered marks surfaced. Coined compound word, low conflict risk. |
| Brand-adjacent: "Kind App" (healthcare) | App Store | ⚠️ Exists but distinct goods/services class (healthcare patient comms vs. utilities/photo). Different mark from "KeepKind". |

**Conclusion:** Lock in `KeepKind: Photo Declutter`. Buy `keepkind.app` and `kindapps.app` today (~$15–20/year each via Cloudflare Registrar or Google Domains). Skip the squatted `.com` — App Store search drives discovery, not direct URL typing.

**Trademark risk plan:** File Intent-to-Use trademark application ourselves (~$350 USPTO fee) once we have public-facing artifacts. Optional but provides legal defense for the Kind Apps brand family.

**Open follow-ups:**
- Purchase `keepkind.app` + `kindapps.app` (today)
- Reserve App Store Connect name "KeepKind: Photo Declutter" (when Apple Dev is confirmed active)
- Decide whether to attempt to acquire `keepkind.com` from the Chinese squatter (likely $1k+ — skip unless we hit App Store traction)

---

## 2026-05-25 — Tech stack locked

**Decision:** Native SwiftUI iOS app, iOS 17+, SwiftData, MetricKit-only diagnostics.

**Rationale:**
- Native gives best performance for PhotoKit/Vision-heavy workload
- SwiftUI faster to ship beautiful UI than UIKit
- iOS 17+ covers ~90% of active devices and unlocks SwiftData
- MetricKit (Apple-native) honors the no-tracking pledge — no Sentry/Firebase/Crashlytics

**Rejected alternatives:**
- React Native / Expo — slower for PhotoKit-heavy work, harder Vision integration
- Flutter — same as above plus less mature on iOS-specific APIs

---

## 2026-05-25 — Infrastructure mirrors BlueBook bootstrap (adapted)

**Decision:** Reuse `grifjef` GitHub org, `grifjef.atlassian.net` Jira, `grifjef-1773158363073.atlassian.net/wiki` Confluence, `sonarcloud.io/organizations/grifjef` SonarCloud. Swap web-specific pieces (Vercel, Playwright, npm) for iOS equivalents (TestFlight, XCTest, SPM).

**Rationale:** Consistent project-management surface across BlueBook + KeepKind. Faster setup. SonarCloud supports Swift.

---

## 2026-05-25 — Sonar choice: SonarCloud (not self-hosted)

**Decision:** Use SonarCloud at `sonarcloud.io/organizations/grifjef` (matches BlueBook).

**Rationale:** Confirmed by user. Same org, free for public repo.

---

## 2026-05-25 — Build order: Large Videos + Screenshots before Similar Photos

**Decision:** Ship Large Videos + Screenshots modules in Phase 1 (today). Similar Photos engine is Phase 3 (this week).

**Rationale:** Per spec §8, Large Videos and Screenshots need zero AI and have low false-positive risk. They deliver immediate "I freed 8GB" payoff. Similar Photos is where false positives can destroy trust — weeks of careful tuning, not hours. Shipping the easy wins first validates the architecture, earns user trust, and gives us something to submit to App Store today.

---

## 2026-05-25 — Today's deliverable scoped

**Decision:** Today's "deployed and working great" means:
- App fully built with Large Videos + Screenshots modules, polished
- Running on user's iPhone (sideloaded or via TestFlight)
- App Store Connect listing complete (name, subtitle, description, keywords, screenshots, privacy)
- Submitted to App Store for review

**Not today:** Similar Photos engine (Phase 3, this week), Blurry shots (Phase 4), App Store live (controlled by Apple review window — 1–7 days).

**Rationale:** Apple's review queue is gated by Apple, not by us. "Live in App Store today" is physically impossible. The honest version of "deployed today" for iOS is "submitted today; reviewer approves and goes live within a week."
