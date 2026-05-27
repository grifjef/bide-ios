# Similar-photo algorithm

> Engineering notes for `SimilarityClusterer` + `VisionService` + `SimilarPhotosScanService`. If you change the clustering pipeline, update this doc in the same PR. Conservative defaults beat aggressive ones — false positives kill trust faster than missed clusters.

---

## The problem

We want to find clusters of near-duplicate photos so a user can pick a "keeper" and move the rest to Recently Deleted. The naive approach — compute a feature print for every photo in the library, then do an all-pairs distance check — is O(n²) and dies on a 10k-photo library. We need to do less work.

## The strategy

Three observations make the algorithm tractable:

1. **Similar photos are taken close together in time.** A burst, a 30-second portrait session, a wedding-cake-shot sequence — they all happen in seconds-to-minutes. Photos taken hours apart are not "similar duplicates" in any useful sense.
2. **Most of the library isn't a cluster candidate.** A library with 10k photos might have 200 burst sequences. The rest don't need pairwise comparison.
3. **Vision's `VNGenerateImageFeaturePrintRequest` gives us a small `VNFeaturePrintObservation` per image that supports a direct `computeDistance(_:to:)` call.** Near-duplicates land below ~10 in that distance space; related-but-distinct shots are 10-25; unrelated images are 25+.

So the pipeline is:

```
  fetch candidates → bucket by time → only buckets with ≥2 → feature print each →
  cluster within bucket → pick keeper → render
```

Each step throws away work for the next.

---

## Step 1 — Fetch

`PhotoLibraryService.fetchPhotoCandidates(limit: 500)` returns `[SimilarPhotoCandidate]` — value structs with the metadata we need for both clustering (creation date) and keeper scoring (favorite/edited/album/Live/resolution). Capped at 500 for first-scan latency. Sorted by `creationDate ascending` so time bucketing is deterministic.

For v0.3 we'll persist this set in SwiftData (the `IndexedAsset` model is already defined) so subsequent scans can resume incrementally.

## Step 2 — Time bucketing (pure)

`SimilarityClusterer.timeBuckets(_, date:, window: 3600)` is a pure function: adjacency-by-date with a windowed gap.

- Input: `[T]`, a date accessor `T → Date`, and a window in seconds (default 1 hour).
- Sort by date ascending.
- Start a new bucket whenever the gap from the current bucket's *start* exceeds the window.

Two photos at 11:59:59 and 12:30:01 belong to the same bucket. A photo at 13:01:00 starts a new one because it's > 60 minutes from the 11:59:59 start.

We chose "gap from start" over "gap from previous" deliberately. A burst that runs from 12:00 to 12:45 should be one cluster; if we used "gap from previous" we could chain across hours via many close-spaced photos. The windowed-from-start version drops the chain at the hour boundary, which is what we want.

The window is a constant in `defaultTimeWindowSeconds`. If real-world testing shows we miss legitimate clusters (e.g. a slow wedding-portrait session that takes 90 minutes), we'd widen the window — but **only after** confirming the false-positive rate doesn't explode.

Bucket boundary is **inclusive** at the window edge (`<= window`), tested in `test_timeBuckets_windowBoundaryInclusive`.

## Step 3 — Feature prints (Vision)

For each candidate in a multi-item bucket:

1. Request a 256×256 thumbnail via `PhotoLibraryService.requestThumbnail(for:targetSize:)`. `isNetworkAccessAllowed = false` — see [photokit-usage.md](./photokit-usage.md) for why.
2. Pass it to `VisionService.featurePrint(for:)`, which wraps `VNGenerateImageFeaturePrintRequest` pinned to `currentRevision`.
3. If either step returns `nil` (iCloud-only and not downloaded; image was deleted between fetch and request), drop the candidate from this bucket. We don't fail the scan — we just have fewer candidates than expected.

Why the revision pin: if Apple ships a new feature-print revision in a future iOS, distances are no longer comparable across versions. Mixing prints would give garbage results. When the revision changes, we should re-cluster from scratch. The persisted `featurePrintVersion` on `IndexedAsset` (v0.3 work) is the gate for that.

256×256 is a deliberate floor. Smaller (128×128) loses too much edge structure. Larger (512×512) is slower with no quality gain in our tests.

## Step 4 — Distance clustering (pure)

`SimilarityClusterer.clusterByDistance(_, distance: { … }, threshold: 12.0)` is generic over `T`, with the distance function injected. Production code passes a closure that calls `vision.distance(from:, to:)`. Tests pass a closure that reads from a `Dictionary<Set<String>, Float>`.

The implementation is union-find:

```swift
for i in 0..<n {
    for j in (i+1)..<n {
        if let d = distance(items[i], items[j]), d < threshold {
            union(i, j)
        }
    }
}
```

Within a bucket of 10 candidates, that's 45 comparisons — fine. We never run this across the full library because Step 2 already chopped the input into small chunks.

The threshold is `defaultDistanceThreshold = 12.0` (Vision feature-print units). Tuning notes:

| Threshold | Behavior |
|---|---|
| ≤ 8 | Only near-exact duplicates cluster. Misses obvious similar shots. |
| 10–12 | Recommended range. Bursts and same-scene shots cluster; distinct photos do not. |
| 15+ | Starts merging "two photos of the same room from different angles" — feels wrong to users. |

We default to 12 and don't expose it as a setting. If field reports show too-aggressive clustering, lower it; not the other way around.

## Step 5 — Keeper selection (pure)

For each cluster ≥ 2 members, `SimilarityClusterer.pickKeeper(_)` picks the suggested keeper:

1. **Favorite is a hard win.** If anything in the cluster is favorited, that's the keeper. Full stop.
2. Otherwise, prefer in this order:
   - Has been edited
   - Is in a user album
   - Is a Live Photo
   - Higher resolution
   - Newer creation date (final tiebreaker)

Implementation is a single `max(by:)` walk over the candidates with each tier evaluated in turn.

The product principle: the keeper is *almost always* the one the user spent the most signal on. Favoriting is the strongest signal. Editing means "I cared enough to fix something." Adding to an album means "I curated this." Live Photo and resolution are weaker but still meaningful.

We surface a plain-English explanation via `keeperReason(_, keeperId:)`. The user trusts the suggestion only if they understand why:

- `"Suggested because it's favorited."`
- `"Suggested because it's been edited."`
- `"Suggested because it's in an album."`
- `"Suggested because it's a Live Photo."`
- `"Suggested because it has the highest resolution."` (only when resolution is the tiebreaker)
- `"Suggested keeper."` (when nothing distinguishes)

Per spec: "People trust explanations." This is the most important six lines of copy in the app.

## Step 6 — Render

Clusters of ≥ 2 are emitted as `PhotoCluster` records. `SimilarPhotosScanService` sorts them by `representativeDate` descending (newest first) so the user sees the most recent cluster first when they open the view.

UI: `SimilarPhotosView` shows a card per cluster (up to 3 thumbnails stacked, count, reclaimable bytes hint). Tap a card → `ClusterReviewView` shows the suggested keeper big, the reason below, and the other candidates as tap-to-add-to-basket rows.

**Crucially: the non-keeper candidates are NOT pre-selected for deletion.** The user has to tap each one to add to the basket. This is the trust mechanism. We do not show a "Delete all but the keeper" button. We do not show a "Delete N of M with one tap" affordance. Every removal is a per-item decision.

---

## Why it's not faster

Critic's question: "Why don't you persist feature prints and skip recomputing them on every scan?" Answer: we will. That's v0.3. For v0.2, the scan limit of 500 keeps the first-scan latency around 10–30 seconds on a modern iPhone, which is tolerable for a feature that ships its results into a persistent UI. Once `IndexedAsset.featurePrintData` is wired up, we re-run only on new photos.

## Why it's not smarter

Critic's question: "Why not use a learned similarity model trained on Bide-specific data?" Answer: zero training data, zero infrastructure for it, and Apple's feature print is already good enough. The day Apple ships a notably better model in a new iOS, we update `VisionService.currentRevision` and re-cluster.

## What the tests cover

`SimilarityClustererTests` (19 tests) exercises:

- **timeBuckets**: in-window grouping, out-of-window splitting, unsorted input is sorted first, window boundary is inclusive, empty input.
- **clusterByDistance**: groups below threshold, singletons preserved, transitive merging (A~B, B~C → {A, B, C}), empty input.
- **pickKeeper**: favorite always wins, edited beats resolution, album beats Live, higher resolution as tiebreaker, newer when all else equal, single-candidate case.
- **keeperReason**: favorite/edited/resolution/fallback message content.

Vision distances themselves aren't unit-tested — they're integration-tested via real-photo manual review. We'd need a labeled corpus to assert against `vision.distance(from:, to:)` numerically, and that's a future infrastructure investment.

---

## Engineering memos to preserve

Worth keeping in mind as the algorithm evolves:

1. **Bucket-first stays.** Whatever future improvements happen, do not start computing pairwise distances on the full library. The time window is the firewall.
2. **Conservative thresholds stay conservative.** Below-12 means "very similar". The fact that we miss "loosely related" pairs is a feature.
3. **Favorite is always the keeper.** Even if a higher-resolution non-favorite exists.
4. **The recommendation is a suggestion, not a default.** We tap "Suggested" not "Best". The UI never says "Delete the others".
5. **One feature-print revision per persisted print.** If we ever start mixing revisions, distances are garbage.
6. **Bucket > full-library by orders of magnitude.** A 50k-photo library with 500 clusters of avg-size 4 photos does 500 × C(4, 2) = 3 000 distance comparisons. The naive all-pairs version does C(50k, 2) ≈ 1.25 billion. Don't let "small optimization" PRs erode this.
