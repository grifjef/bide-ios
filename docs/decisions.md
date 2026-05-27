# Decisions log

> Running log of significant decisions and their rationale. Newest at top.

---

## 2026-05-27 — Bide v1.0 (build 1) submitted to the App Store

**Status:** 1.0 Waiting for Review

Submitted at ~10:55 AM PT. Apple's auto-response says "up to 48 hours" — first-time submissions usually clear in 24h if there are no flags.

What's in this version (v0.1.0 / build 1):
- Onboarding (3 pages)
- Dashboard with module cards
- Large Videos module (fully working: scan → review → Review Basket → delete via Recently Deleted)
- Screenshots module placeholder ("coming soon")
- Settings with privacy promise
- App Privacy nutrition label: **Data Not Collected**
- Age rating: **4+**
- Price: Free in all 175 countries

Apple Connect IDs (for future reference):
- App ID: `6773746241`
- AppStoreVersion ID: `0cd3d00f-a0f9-4e50-8591-0a7015a5ef6c`
- Build ID: `8b2f8469-aaba-4a74-9353-0e381c280229`
- Bundle ID internal: `84M8PH643H`
- Profile ID: `6B8SAPTJW9` (Bide App Store)

Notable shortcuts vs. the BlueBook bootstrap plan:
- xcodebuild + altool driven entirely via App Store Connect API key (no Xcode sign-in needed)
- Provisioning profile created via API rather than Xcode auto-fetch
- Screenshot uploaded via 3-step App Store Connect API (no drag-drop)

---

## 2026-05-27 — Atlassian deactivated; pivot to GitHub Issues + docs/ markdown

**Decision:** Defer Jira/Confluence integration indefinitely. Use GitHub Issues for issue tracking and `docs/` markdown for project documentation.

**Why:** The Atlassian workspace at `grifjef.atlassian.net` was discovered deactivated due to inactivity — Jira and Confluence both return 503 with a "Your Jira Cloud subscription has been deactivated, data will be permanently deleted soon" page. The Atlassian status page shows all systems operational globally, so this is workspace-specific, not a global outage.

**State:**
- An Atlassian API token named "Bide" was created and is saved at `.secrets/atlassian.env` (gitignored, mode 600). It authenticates against id.atlassian.com (account-level) but cannot be used against grifjef.atlassian.net while the workspace is deactivated.
- All references to Jira project BD and Confluence space BD in `PLAN.md`, `CLAUDE.md`, and skill docs remain as the **future-state architecture** — they describe what happens if/when Atlassian is reactivated.

**How to apply:**
- New issues / tasks → GitHub Issues on `grifjef/bide-ios`
- New documentation → markdown file in `docs/`
- If user reactivates Atlassian via the contact-us link, the API token + skill recipes in `.claude/skills/jira-flow/` and `.claude/skills/confluence-doc/` make spin-up a one-shot job

---

## 2026-05-25 — Final name: **Bide**

**Decision:** Project renamed from KeepKind → Bide.

**App Store name:** Bide: Camera Roll Review
**Tagline:** Bide your time. Keep what matters.
**Subtitle:** Camera roll, at your pace
**Bundle ID:** `com.bidephoto.bide`
**Primary domain:** `bidephoto.com` (to purchase)
**Defensive domains:** `bidephotos.com`, `usebide.com`, `bidethe.app`

### Why we changed from KeepKind

User feedback: KeepKind sounded healthcare-adjacent / kid-app-ish. The "Kind Apps" parent brand framing was dropped along with the name.

### The search and what we learned

| Candidate | Outcome | Why eliminated |
|---|---|---|
| Winnow (initial pick after rejecting KeepKind) | ❌ | 5 active App Store apps using "Winnow" + Winnow Solutions (B2B food-waste AI, 94 countries, likely trademarked) + every domain variant taken (.app, .com, .io, .co, .photo, .photos, .studio, .gallery, .so, .ink, .fyi + every get/try/use/-app variant) |
| Cull | ❌ | Direct App Store competitor exists: "Cull - AI Photo Cleaner" |
| Keepsake | ❌ | 5 apps in App Store including "Keepsake Frames" (Photo & Video) |
| Memento | ❌ | 9 apps including "Memento - Lasting Moments" (Photo & Video) |
| Cairn | ❌ | 7 apps in App Store, all domains taken |
| The Edit | ❌ | Editor/edit space is saturated |
| Glade | ⚠️ | 0 App Store conflicts but SC Johnson air-freshener trademark exposure (different class but litigious $20B company) |
| Pith | ⚠️ | 1 non-photo App Store conflict + two .com variants available |
| **Bide** | ✅ | **0 App Store conflicts; bidephoto.com + 3 defensive domains available; no major trademark holder** |

**Universal observation:** essentially every common short English word is squatted across every reasonable TLD in 2026. The naming exercise was less "pick a great word" and more "find a word that survived the speculative-domain era."

### Why Bide

- **Zero App Store apps** start with "Bide" — cleanest possible discovery
- **bidephoto.com**, **bidephotos.com**, **usebide.com**, **bidethe.app** all available for purchase (~$12/yr each)
- **No major trademark holder** to dispute
- The word "bide" — *to dwell, to wait patiently* — is the entire product philosophy in one syllable
- Slight obscurity is a feature: gives us something to teach, which builds brand memory
- Real English word, not invented — survives "what does that name mean?" questions

### Open follow-up

- Purchase `bidephoto.com` + 2-3 defensive variants (today)
- Reserve App Store Connect name "Bide: Camera Roll Review" once Apple Developer is confirmed active
- File Intent-to-Use USPTO trademark on BIDE in class 9 (mobile software) once we have public-facing artifacts (~$350 fee, optional)

---

## 2026-05-25 — Drop "Kind Apps" parent-brand framing

**Decision:** No parent brand umbrella for Bide. PageKind (the user's separate scanner app) and Bide stand alone, sharing infrastructure but not branding.

**Rationale:** User feedback that "KeepKind" sounded healthcare-adjacent extended to the broader "Kind Apps" framing. Each app in the portfolio can earn its own identity.

**Open:** Revisit if a third app is added and a unifying brand becomes worth investing in.

---

## 2026-05-25 — Name verification: KeepKind cleared (*superseded — see Bide entry above*)

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
