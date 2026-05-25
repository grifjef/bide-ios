# KeepKind — Product Specification

> **Source:** Original product spec authored by user, preserved verbatim. This is the source of truth for product decisions.

---

## Product summary

**A private photo review app that helps people reclaim their camera roll safely.**

The emotional promise is not "optimize storage."

It is:

> **Clean up your photos without accidentally losing memories.**

That is the whole game.

---

## 1. Market reality

The iPhone photo cleanup category is large, ugly, and crowded.

The demand is obvious: people take too many photos and videos, iPhone storage fills up, iCloud storage gets expensive, and normal people do not want to scroll through 38,000 photos one by one.

The competition proves the demand:

- **Cleanup: Phone Storage Cleaner** — duplicate photos, videos, junk email, video compression, camera-roll cleanup
- **Cleaner Kit** — duplicate photo cleanup, video cleanup, blurry photo detection, screenshots, storage cleanup
- **Smart Cleaner** — multiple App Store variants around AI duplicate photo removal, storage cleanup, similar photos, contacts, video compression, widgets
- **Swipewipe** — "reclaim your camera roll" with a simple swipe-based review flow
- **Clever Cleaner** — already claims 100% free, no subscriptions, no pro plans, no ads

That last point matters: the "free, no ads" lane is not empty. We cannot win merely by saying "free and private." We need a better concept.

## 2. Apple already does part of this — but not enough

Apple Photos already identifies duplicate photos and videos in a Duplicates collection and lets users merge them.

But Apple's built-in duplicates tool is not the full problem. People do not only have exact duplicates. They have:

- 11 nearly identical kid/sports photos
- screenshots from two years ago
- accidental screen recordings
- huge videos
- blurry photos
- "just in case" photos
- memes
- saved receipts
- school screenshots
- pictures of parking spots, menus, confirmation codes, recipes, Wi-Fi passwords, homework, and random stuff

Apple's built-in duplicate tool is useful, but it is not a guided review system for real-life camera-roll clutter.

That is the opening.

## 3. The correct wedge

Do **not** compete as:

> "AI phone cleaner."

That sounds scammy.

Compete as:

# **The safe camera-roll review app**

Better language:

> **Review your cluttered camera roll in calm, safe sessions. Keep the memories. Clear the junk. Nothing leaves your phone.**

This reframes the app from deletion to discernment.

The user is not trying to "clean storage." They are trying to answer:

> "What can I safely get rid of without losing anything important?"

That is a deeper, more human problem.

## 4. Product name strategy

**Decision: KeepKind: Photo Declutter**

App Store name: **KeepKind: Photo Declutter**
Tagline: **Keep the memories. Clear the clutter.**
Subtitle: **Safe camera roll cleanup**

Brand family: **Kind Apps** — simple public-good apps with no ads, no accounts, no tricks. Siblings include PageKind (scanner).

### Naming principles

Avoid: cleaner, booster, optimizer, AI cleaner, smart cleaner, phone cleaner, sweep, clean up, junk, delete, magic. Those are category-poisoned words.

Use names that feel: safe, calm, private, human, trustworthy, memory-oriented, not scammy.

### Backup names (in case KeepKind is unavailable)

1. **PhotoKind: Camera Roll Review** — "A kinder way to clean up photos."
2. **TidyRoll: Photo Declutter** — "Tidy your camera roll safely."
3. **MemoryKind: Photo Declutter** — "Protect the memories. Remove the noise."
4. **RollSafe: Photo Declutter** — "Clean your camera roll without the panic."

## 5. Core product thesis

### Promise

> **Clean up your camera roll safely, privately, and without ads.**

### Public-service pledge

- Free
- No ads
- No subscriptions
- No account
- No tracking SDKs
- No uploading photos to our servers
- No one-tap mass deletion without review
- No fake "danger" warnings
- No dark-pattern paywall

### Product personality

Calm, safe, respectful. Not urgent, spammy, gamified, scare-mongering, or fake-AI-magical.

## 6. Competitive positioning

### What incumbents do

Most cleaner apps compete on:

- "AI cleaning"
- one-tap deletion
- duplicate detection
- storage recovered
- video compression
- contact cleanup
- battery widgets
- secret folders
- subscription bundles

Cleaner apps often sprawl into unrelated utilities: contacts, calendars, email cleanup, charging animations, widgets, internet speed tests, and battery-life content.

### What we do differently

KeepKind competes on:

- trust
- safe review
- clarity
- no pressure
- local processing
- memory preservation
- graceful cleanup sessions
- zero monetization dark patterns

Positioning statement:

> **KeepKind is not a phone cleaner. It is a private camera-roll review tool that helps you keep what matters and remove what does not.**

## 7. Product principles

Rules we will not violate.

1. **Never auto-delete memories.** The app can recommend. The human decides.
2. **Make every delete feel reversible.** Apple's Recently Deleted holds items 30 days — communicate that clearly.
3. **No scare tactics.** Never say "Your iPhone is at risk", "Critical storage warning", "Junk detected", "Your phone is slow because of photos".
4. **No hidden cloud.** "Analysis happens on your iPhone. We do not upload your photos."
5. **Deletion should be batchable but never careless.**
6. **Default to preserving people.** Conservative around faces, pets, children, events, rare dates.
7. **Patient assistant, not garbage disposal.**

## 8. MVP product

### MVP goal

Help a user safely free meaningful storage in under 10 minutes without fear.

### MVP modules

#### 1. Large Videos

Easiest, highest-impact first module.

Flow: scan video assets → sort by size descending → show thumbnail/duration/date/file size → user reviews → user selects → final confirmation → delete via PhotoKit.

Why first: Video files are the biggest offenders. No complex AI needed. Very low false-positive risk. User immediately sees payoff.

#### 2. Screenshots

Second easiest.

Flow: fetch screenshots using media subtype → group by month/year → show old first → bulk-select obvious groups → safe exceptions for screenshots with QR codes, confirmation numbers, last 30 days, or favorited.

Screenshots are usually clutter, but sometimes they are important. App must respect that.

#### 3. Similar Photo Groups

Core magic.

Flow: group photos taken near the same time and/or visually similar → show clusters → recommend the likely best photo → user compares side-by-side → user keeps one or more → delete the rejected ones only after final confirmation.

Technical foundation: Vision framework `VNGenerateImageFeaturePrintRequest` for image similarity.

#### 4. Blurry / Low-Quality Candidates

Do not call them "bad photos." Call them "Review blurry shots."

Flow: detect blur / low contrast / very dark images → group as "Maybe remove" → user reviews manually → app never assumes.

#### 5. Review Basket

Before deletion, nothing is deleted.

All selected items go into a local review basket: photos selected, videos selected, estimated storage, reason selected, thumbnail grid, remove-from-basket option, final confirmation.

Final copy:

> "These items will move to Recently Deleted in Photos. You can recover them there for 30 days."

## 9. What the app does NOT include in v1

Avoid: contact cleanup, email cleanup, calendar cleanup, battery widgets, charging animations, secret vault, VPN, device speed booster, malware-like language, fake scan animations, paid wall before deletion, cloud backup, face-recognition naming, "delete all recommended" as primary CTA, permanent deletion from Recently Deleted.

## 10. Full v1 user experience

### First launch

One screen:

> **Clean up your camera roll safely.**
> KeepKind helps you review large videos, screenshots, and similar photos. Everything is analyzed on your iPhone. No ads. No account. No subscription.

Buttons: Start Review, How privacy works.

Then permission screen with honest copy:

> "KeepKind needs photo access to find clutter. You can limit access, but full-library access gives the best cleanup results."

### Home dashboard

Top: Storage reviewed, Potential space to recover, Photos reviewed, Current session progress.

Cards:
1. **Large Videos** — "12 videos using 8.4 GB"
2. **Screenshots** — "642 screenshots"
3. **Similar Photos** — "94 groups to review"
4. **Blurry Shots** — "37 candidates"
5. **Recent Imports** — "Review what you saved this month"

Bottom: Review Basket, Privacy Promise, Settings.

### Large video flow

Card view: thumbnail, date, duration, size, location if available, play preview.
Buttons: Keep / Delete Candidate / Favorite-Protect.
Batch mode: select many, add to basket, final review.

### Screenshot flow

Group by year, month, app/source if inferable, text type (receipts, codes, recipes, conversations, maps, shopping).

Fast review: grid, tap to expand, select range, keep important, add rest to basket.

### Similar photo flow

Most important UX.

Cluster screen: large recommended keeper, comparison strip, score indicators (sharpest, highest resolution, favorited, edited, Live Photo, has faces, smiles/open eyes later).
User chooses: Keep this one / Keep all / Choose manually / Add others to basket.

Never say "We picked the best." Say "Suggested keeper."

### Review Basket

The trust center. Sections by module. For each: thumbnail, date, size, reason, restore-to-keep option.

Final action: **Move to Recently Deleted** (not "Delete forever").

After: "You moved 183 items to Recently Deleted. They can be recovered in Photos for 30 days."

## 11. Future roadmap

### v1.1: Safer and smoother
- "Protected items" list
- Never suggest favorites by default
- Never suggest hidden by default
- Never suggest photos from last 7/14/30 days by default
- Better progress resume if scan interrupted
- Better battery/heat management
- Better iCloud Photos handling copy

### v1.5: Better memory intelligence
- Event clusters, trip clusters, kid/sports burst cleanup, "Best of a moment"
- More accurate blur detection
- Screenshot OCR buckets (receipts, codes, tickets, forms, maps, shopping, conversations)
- Duplicate Live Photo slimming

### v2.0: Photo Library Habit System
- Weekly 5-minute review
- "On this day, clean old screenshots"
- "Review last month"
- "Review large videos from this season"
- Inbox Zero for camera roll
- Optional local reminders

### v3.0: Family helper mode
- "Install this on Mom's phone"
- Simplified senior-friendly UI
- Extra-safe deletion copy
- Big text mode
- Fewer controls
- Guided cleanup

## 12. Technical architecture

### Core frameworks

- SwiftUI
- PhotoKit
- Vision
- Core Image
- Core ML if needed later
- SwiftData or SQLite for local index
- BackgroundTasks (carefully)
- AVFoundation for video thumbnails/durations

### Photo access

PhotoKit is the core. `PHPhotoLibrary` authorization and change APIs (including limited-library behavior).

Needed:
- Fetch assets
- Request thumbnails
- Request full-size images selectively
- Compute metadata
- Store local feature index
- Delete selected assets through `PHAssetChangeRequest.deleteAssets(_:)` inside a change block

### Local index

Do not rescan everything every launch.

**AssetIndex** table:
- localIdentifier
- mediaType
- mediaSubtypes
- creationDate
- modificationDate
- pixelWidth
- pixelHeight
- duration
- estimatedFileSize
- isFavorite
- isHidden
- burstIdentifier
- sourceType
- lastAnalyzedAt
- thumbnailHash
- featurePrintVersion
- clusterId
- riskLevel

**Cluster** table:
- id
- type (duplicate / similar / screenshot / video / blurry)
- createdAt
- representativeAssetId
- estimatedRecoverableBytes
- confidence
- reviewStatus

**ReviewDecision** table:
- assetId
- decision (keep / deleteCandidate / protected / ignored)
- reason
- timestamp

**Session** table:
- id
- startedAt
- completedAt
- assetsReviewed
- bytesSelected
- deleteCompleted

### Processing model

Five stages:
1. Lightweight library scan (metadata only)
2. High-impact candidates (large videos, screenshots, screen recordings, bursts, exact metadata duplicates)
3. Visual similarity (request thumbnails or medium images, generate feature prints, group by time window first, compare within constrained buckets)
4. Quality scoring (blur, exposure, faces later, smiles/open eyes later)
5. Recommendation generation (conservative, explainable, user-review-first)

## 13. Similar-photo algorithm

Do not compare every photo to every other. That dies on big libraries.

### Practical approach

1. **Bucket by time** — same day, same hour, burst identifier, same location radius, same dimensions/device metadata.
2. **Generate feature print** — `VNGenerateImageFeaturePrintRequest`.
3. **Compare within buckets** — feature distances only inside candidate buckets.
4. **Cluster** — threshold-based: exact / near-exact / strong similars / weak similars. Conservative early.
5. **Suggest keeper** — favorited = protect; edited = prefer; higher resolution = prefer; less blurry = prefer; Live Photo = prefer; appears in album = prefer; user previously protected similar = prefer.
6. **Explain recommendation** — "Suggested because it is sharper." "Suggested because it is favorited." "Suggested because it has higher resolution." "Suggested because it appears edited."

People trust explanations.

## 14. Safety model

Lives or dies on safety.

### Risk levels

**Low risk:**
- Old screenshots
- Screen recordings over 1GB
- Exact duplicates
- Blurry accidental shots with no faces

**Medium risk:**
- Similar photos
- Memes
- Receipts
- Downloaded images

**High risk:**
- Photos with faces
- Favorites
- Hidden photos
- Photos in albums
- Old rare photos
- Photos around major dates
- Live Photos
- Edited photos
- Photos with location/travel signal

Default: high-risk items are not auto-selected. Protected categories excluded unless user explicitly opts in.

### Protected by default

Never recommend deletion by default for:
- Favorites
- Hidden photos
- Photos less than 30 days old
- Album-cover-like images
- One-of-one photos from a date/location
- Photos with people unless part of a tight similar cluster
- Edited photos unless duplicate exists
- Screenshots with likely confirmation code/ticket/receipt until user reviews

### Deletion copy

Never "Delete forever." Use: "Move selected items to Recently Deleted." Then: "Photos keeps deleted items for 30 days before permanent deletion."

## 15. Privacy model

### Architecture claims (if implemented as planned)

- No backend
- No account
- No photo upload
- No third-party analytics SDKs
- No ad SDKs
- No tracking permission prompt
- Local-only index
- Optional crash diagnostics only through Apple

### In-app privacy copy

> KeepKind analyzes your photo library on your iPhone. We do not upload your photos, sell data, show ads, or require an account.

Caveat:

> If you choose to share, export, back up, or sync photos through Apple, iCloud, or another app, that service controls what happens next.

### Privacy policy

Short and plain: what permissions are used, what data is stored locally, no server upload, no ads, no tracking, no sale of data, no account, how deletion works, how to delete local app data, Apple diagnostics caveat.

## 16. App Store strategy

### App Store name

**KeepKind: Photo Declutter**

### Subtitle

**Keep memories. Clear clutter.** (alternative: "Safe camera roll cleanup")

### Keywords

photo cleaner, camera roll, duplicate photos, similar photos, delete photos, photo declutter, clean photos, storage cleanup, large videos, screenshots, free photo cleaner, no ads photo cleaner, private photo cleaner

### Screenshots

1. Clean your camera roll safely
2. Find large videos fast
3. Review old screenshots
4. Compare similar photos
5. You choose what goes
6. Nothing uploaded by us
7. No ads. No account. No subscription.

### Description opening

> KeepKind helps you review your camera roll and safely clear photo clutter. Find large videos, old screenshots, similar photos, and blurry shots. Keep what matters, move the rest to Recently Deleted, and reclaim space without ads, accounts, subscriptions, or cloud uploads by us.

## 17. Website strategy

Domain candidates (verify availability):
- `KeepKind.app`
- `GetKeepKind.com`
- `KeepKind.co`
- `KeepKind.com`

### Homepage

Headline: **A safer way to clean up your camera roll.**
Subhead: KeepKind helps you review large videos, screenshots, and similar photos privately on your iPhone. No ads. No account. No subscription. No photo uploads by us.

Sections: Hero, How it works, Safety promise, Privacy promise, What it finds, FAQ, App Store link, Privacy policy.

### FAQ

- Does KeepKind upload my photos?
- Does it delete photos automatically?
- Can I recover deleted photos?
- Why does it need photo access?
- Does it work with iCloud Photos?
- Is it really free?
- How is it different from Apple Photos Duplicates?
- How is it different from phone cleaner apps?

## 18. Marketing strategy

### The enemy

Not a named competitor. The enemy is:

> **The anxiety of losing memories and the annoyance of scammy cleaner apps.**

### Core marketing line

> **The photo cleaner for people who do not trust photo cleaners.**

### Launch story

> "I built a free, private iPhone app because photo cleaner apps are one of the grossest categories in the App Store. This one has no ads, no account, no subscription, no cloud upload, and no automatic deletion."

### Target audiences

1. **Parents** — "Keep the memories. Clear the 17 near-identical shots."
2. **Travelers** — "Clean up after a trip without losing the best moments."
3. **Students** — "Clear old screenshots and class clutter in minutes."
4. **Adult children helping parents** — "A safe camera-roll cleanup app you can put on your parents' phone."
5. **Privacy-conscious tech users** — "No cloud. No tracking. No ads. No paywall."

### Channels

- App Store Search (most durable)
- TikTok/Reels/Shorts (before/after demos)
- Reddit (r/iosapps, r/iphone, r/apple, r/privacy, r/parenting, r/declutter)
- Parent Facebook groups
- Local community (libraries, school parent groups)
- Influencer angle (creators who complain about full storage)

## 19. MVP build plan

### Phase 0: Competitor teardown (3–5 days, can run in parallel with build)

Install and test: Cleanup, Cleaner Kit, Smart Cleaner, Clever Cleaner, Swipewipe, slide/slider-style cleaners, Apple Photos Duplicates.

For each: first-run flow, permission language, paywall timing, ads, subscription pressure, scan speed, trust feeling, deletion flow, recovery clarity, over-selection, favorites handling, recent-photo handling, App Store messaging.

### Phase 1: Technical spike (1 week)

Prove end-to-end deletion flow safely: PhotoKit access → fetch assets → list large videos → list screenshots → show thumbnails → select candidates → delete through PhotoKit → confirm Recently Deleted behavior.

### Phase 2: MVP (3–5 weeks)

Onboarding, dashboard, large video module, screenshot module, review basket, deletion confirmation, local privacy settings, scan progress, TestFlight.

Do **not** start with similar-photo AI. Large videos and screenshots can already help users and validate trust.

### Phase 3: Similar photo engine (3–6 weeks)

Feature print generation, time bucket clustering, cluster review UI, keeper suggestion, conservative thresholds, protected item rules, performance controls.

### Phase 4: TestFlight (2–3 weeks)

Test with 10 parents, 10 students, 10 older adults / adult children helping parents, 10 tech/privacy people, 10 heavy photo users.

Questions: Did you trust it? Did it feel safe? Did it find useful clutter? Did you understand deletion? Did anything scare you? Would you keep it installed? Would you recommend it? Did it make your phone feel lighter?

### Phase 5: Launch

Launch with: large videos, screenshots, similar photo groups, review basket, Recently Deleted education, no ads/subscription/account, privacy policy, feedback button.

## 20. Quality bar

### Performance

Must handle: 10,000 assets / 50,000 assets / iCloud Photos partially downloaded / limited photo access / low battery / interrupted scan / app backgrounding / heat throttling / older iPhones.

### UX

Must be: obvious, safe, recoverable, calm, never scary.

### Trust

Must not: surprise-delete, exaggerate storage savings, hide consequences, overpromise privacy, scan hidden/favorites by default, pressure users to delete.

### Legal/App Store

Avoid: "boost performance" claims, undefined "remove junk", malware/security language, deceptive storage urgency, medical/legal/privacy guarantees, child-photo analysis claims that feel creepy.

## 21. Metrics

Public usefulness, not monetization.

### Product metrics (App Store Connect; no third-party SDKs)

- First scan completed
- Assets reviewed
- Items moved to Recently Deleted
- Estimated storage selected
- Module usage
- Crash rate
- Scan interruption rate
- Time to first useful cleanup

### Trust metric

After completion: "Did this feel safe?" Yes / Mostly / No + optional feedback.

### Public-good metrics

- Total estimated storage users reclaimed
- Total users served
- Total ad-free cleanup sessions
- Five-star reviews mentioning "free", "safe", "private", "no ads"

## 22. Biggest risks

1. **Clever Cleaner already owns "free no ads"** — counter: fight on safe/calm/memory-first, not on "free" alone.
2. **Apple improves Photos** — counter: better guided workflow for screenshots/large videos/near-duplicates/blurry/memory-safe cleanup; Apple's built-in is exact duplicates only.
3. **False positives destroy trust** — counter: conservative recommendations, review basket, protected defaults, clear recovery.
4. **Permission friction** — counter: explain plainly; support limited mode; communicate that full access enables full cleanup.
5. **Big libraries are hard** — counter: stage processing, prioritize large videos/screenshots first, avoid O(n²) similarity scans.

## 23. Why this could become beloved

Most cleaner apps make people feel like prey.

KeepKind should make people feel respected.

> "Your photos are your life. We will help you sort them carefully."

That is the differentiator.

## 24. Final recommended product

# **KeepKind: Photo Declutter**

**Promise:** Keep the memories. Clear the clutter.
**Subtitle:** Safe camera roll cleanup
**Website headline:** A safer way to clean up your camera roll.

**MVP:** Large video finder · Screenshot review · Similar photo groups · Blurry shot candidates · Review basket · Move to Recently Deleted · No ads · No account · No subscription · No cloud upload by us.

**Differentiator:** The photo cleaner for people who do not trust photo cleaners.

**Strategic sequence:** Build the scanner first. Then build KeepKind. Tie them together under the **Kind Apps** brand family — simple, private, useful apps with no ads, no accounts, and no tricks.
