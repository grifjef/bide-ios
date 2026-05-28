import Foundation

/// Pure clustering algorithm for similar-photo grouping.
///
/// Strategy (per product spec §13):
///   1. Bucket assets by time (default 1-hour windows). Two photos taken within
///      an hour are *candidates* for clustering; photos taken hours apart are not.
///      This is critical — without it we'd be O(n²) on the whole library.
///   2. Within each bucket, compute pairwise feature-print distance and union
///      anything below `distanceThreshold` into a single cluster.
///   3. Pick a suggested keeper per cluster using `pickKeeper` (favorites > edited >
///      in-album > Live Photo > higher resolution > newer).
///   4. Emit `PhotoCluster` records with the keeper, reason, and the other
///      members. Nothing is ever auto-selected for deletion.
///
/// Thresholds are deliberately conservative — false positives kill trust faster
/// than missed clusters. Default `distanceThreshold` is 12.0 (Vision feature-print
/// units); near-duplicate burst photos land in the 0–8 range, related-but-distinct
/// shots are 12–25, unrelated images 25+.
enum SimilarityClusterer {
    static let defaultDistanceThreshold: Float = 12.0
    static let defaultTimeWindowSeconds: TimeInterval = 60 * 60 // 1 hour

    // MARK: - Burst grouping (pure)

    /// Group candidates by `burstIdentifier`. Returns only groups with ≥ 2
    /// members. Candidates with nil burstIdentifier are ignored (they go
    /// through the feature-print pipeline).
    ///
    /// Burst detection is exact (no thresholds, no Vision needed) — PhotoKit's
    /// burst tag is set by the OS when the user holds the shutter.
    static func burstGroups(_ candidates: [SimilarPhotoCandidate]) -> [[SimilarPhotoCandidate]] {
        var bucket: [String: [SimilarPhotoCandidate]] = [:]
        for candidate in candidates {
            guard let burst = candidate.burstIdentifier else { continue }
            bucket[burst, default: []].append(candidate)
        }
        return bucket.values
            .filter { $0.count >= 2 }
            .map { $0.sorted { $0.creationDate < $1.creationDate } }
    }

    /// Convenience: build a `PhotoCluster` from a burst group, using the same
    /// keeper-selection rules as feature-print clusters. The reason string
    /// includes the burst-specific context.
    static func makeBurstCluster(_ burst: [SimilarPhotoCandidate]) -> PhotoCluster {
        let keeper = pickKeeper(burst)
        let reason = burstKeeperReason(burst, keeperId: keeper.id)
        return PhotoCluster(
            id: UUID(),
            representativeDate: burst.first?.creationDate ?? Date(),
            candidates: burst,
            suggestedKeeperId: keeper.id,
            suggestedKeeperReason: reason
        )
    }

    /// Burst-specific explanation that mentions the burst context. Falls back
    /// to the standard reasons when no burst-specific signal applies.
    static func burstKeeperReason(_ candidates: [SimilarPhotoCandidate], keeperId: String) -> String {
        guard let keeper = candidates.first(where: { $0.id == keeperId }) else {
            return "Suggested keeper from this burst."
        }
        if keeper.isFavorite { return "Suggested from this burst — it's favorited." }
        if keeper.hasBeenEdited { return "Suggested from this burst — it's been edited." }
        if keeper.isInUserAlbum { return "Suggested from this burst — it's in an album." }
        if keeper.isLivePhoto { return "Suggested from this burst — it's a Live Photo." }

        let maxRes = candidates.map(\.resolution).max() ?? keeper.resolution
        let hasResolutionTiebreaker = candidates.contains { $0.resolution < maxRes }
        if keeper.resolution == maxRes && hasResolutionTiebreaker {
            return "Suggested from this burst — highest resolution."
        }
        return "Suggested keeper from this burst."
    }

    // MARK: - Time bucketing (pure)

    /// Group items into buckets where adjacent items (by date) are within `window` seconds.
    /// A new bucket starts when the gap from the bucket's start exceeds the window.
    ///
    /// Returns buckets sorted oldest-first; each bucket is also sorted by date ascending.
    static func timeBuckets<T>(
        _ items: [T],
        date: (T) -> Date,
        window: TimeInterval = defaultTimeWindowSeconds
    ) -> [[T]] {
        guard !items.isEmpty else { return [] }
        let sorted = items.sorted { date($0) < date($1) }

        var buckets: [[T]] = []
        var current: [T] = []
        var bucketStart: Date?

        for item in sorted {
            if let start = bucketStart, date(item).timeIntervalSince(start) <= window {
                current.append(item)
            } else {
                if !current.isEmpty {
                    buckets.append(current)
                }
                current = [item]
                bucketStart = date(item)
            }
        }
        if !current.isEmpty {
            buckets.append(current)
        }
        return buckets
    }

    // MARK: - Distance clustering (pure)

    /// Union-find clustering within a single bucket using an injected distance function.
    /// Items with `distance < threshold` are merged into the same cluster.
    /// Returns groups of size 1 included (callers filter as needed).
    static func clusterByDistance<T>(
        _ items: [T],
        distance: (T, T) -> Float?,
        threshold: Float
    ) -> [[T]] {
        let n = items.count
        guard n >= 2 else { return items.map { [$0] } }

        var parent = Array(0..<n)
        func find(_ x: Int) -> Int {
            var r = x
            while parent[r] != r { r = parent[r] }
            // Path compression
            var c = x
            while parent[c] != r {
                let next = parent[c]
                parent[c] = r
                c = next
            }
            return r
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a); let rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        for i in 0..<n {
            for j in (i + 1)..<n {
                if let d = distance(items[i], items[j]), d < threshold {
                    union(i, j)
                }
            }
        }

        var groups: [Int: [T]] = [:]
        for i in 0..<n {
            groups[find(i), default: []].append(items[i])
        }
        return Array(groups.values)
    }

    // MARK: - Keeper selection (pure)

    /// Score-based keeper selection. Higher precedence rules win.
    /// 1. Favorited (hard win)
    /// 2. Edited
    /// 3. In a user album
    /// 4. Live Photo
    /// 5. Higher resolution
    /// 6. Newer (tiebreaker)
    static func pickKeeper(_ candidates: [SimilarPhotoCandidate]) -> SimilarPhotoCandidate {
        // Favorite is a hard win — if any candidate is favorited, that's the keeper.
        if let favorite = candidates.first(where: { $0.isFavorite }) {
            return favorite
        }
        // Otherwise pick the candidate that wins the most precedence tiers.
        return candidates.max { a, b in
            // Return true if `a` < `b` (i.e. b should win)
            if a.hasBeenEdited != b.hasBeenEdited { return !a.hasBeenEdited }
            if a.isInUserAlbum != b.isInUserAlbum { return !a.isInUserAlbum }
            if a.isLivePhoto != b.isLivePhoto { return !a.isLivePhoto }
            if a.resolution != b.resolution { return a.resolution < b.resolution }
            return a.creationDate < b.creationDate
        } ?? candidates[0]
    }

    /// Plain-English explanation of why `keeperId` was chosen — shown in UI as
    /// the trust signal. Per spec: "People trust explanations."
    static func keeperReason(_ candidates: [SimilarPhotoCandidate], keeperId: String) -> String {
        guard let keeper = candidates.first(where: { $0.id == keeperId }) else {
            return "Suggested keeper."
        }
        if keeper.isFavorite { return "Suggested because it's favorited." }
        if keeper.hasBeenEdited { return "Suggested because it's been edited." }
        if keeper.isInUserAlbum { return "Suggested because it's in an album." }
        if keeper.isLivePhoto { return "Suggested because it's a Live Photo." }

        let maxRes = candidates.map(\.resolution).max() ?? keeper.resolution
        let hasResolutionTiebreaker = candidates.contains { $0.resolution < maxRes }
        if keeper.resolution == maxRes && hasResolutionTiebreaker {
            return "Suggested because it has the highest resolution."
        }
        return "Suggested keeper."
    }

    // MARK: - Full pipeline (pure, distance is injected)

    /// Run the full pipeline. Pure — `distance` is the only side-effecting hook.
    /// In production it wraps `VisionService.distance(...)`; in tests it's a stub.
    ///
    /// Returns only clusters with 2+ members (singletons are dropped).
    static func cluster(
        _ candidates: [SimilarPhotoCandidate],
        featurePrint: (SimilarPhotoCandidate) -> AnyObject?,
        distance: (AnyObject, AnyObject) -> Float?,
        distanceThreshold: Float = defaultDistanceThreshold,
        timeWindow: TimeInterval = defaultTimeWindowSeconds
    ) -> [PhotoCluster] {
        let buckets = timeBuckets(candidates, date: { $0.creationDate }, window: timeWindow)

        var clusters: [PhotoCluster] = []
        for bucket in buckets where bucket.count >= 2 {
            // Resolve feature prints, dropping anything without one (iCloud-not-downloaded etc).
            let withPrints: [(candidate: SimilarPhotoCandidate, print: AnyObject)] = bucket.compactMap { c in
                guard let fp = featurePrint(c) else { return nil }
                return (c, fp)
            }
            guard withPrints.count >= 2 else { continue }

            let groups = clusterByDistance(
                withPrints,
                distance: { a, b in distance(a.print, b.print) },
                threshold: distanceThreshold
            )

            for group in groups where group.count >= 2 {
                let cands = group.map(\.candidate)
                let keeper = pickKeeper(cands)
                let reason = keeperReason(cands, keeperId: keeper.id)
                clusters.append(
                    PhotoCluster(
                        id: UUID(),
                        representativeDate: cands.map(\.creationDate).min() ?? Date(),
                        candidates: cands,
                        suggestedKeeperId: keeper.id,
                        suggestedKeeperReason: reason
                    )
                )
            }
        }

        return clusters.sorted { $0.representativeDate > $1.representativeDate }
    }
}
