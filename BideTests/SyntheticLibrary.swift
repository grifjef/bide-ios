@testable import Bide
import Foundation

/// Deterministic synthetic-library generator for performance + memory
/// benchmarks. Produces `[SimilarPhotoCandidate]` arrays that exercise
/// the pure scan algorithms (dedup, clustering, On This Day) at scale
/// without PhotoKit — the sim has no real photos, and the algorithms
/// are the hot paths anyway.
///
/// Deterministic (seeded by index, no RNG) so benchmark runs are
/// comparable across machines and CI.
enum SyntheticLibrary {
    /// Build `count` candidates spread across a year, with a tunable
    /// fraction that are exact duplicates (same signature) and a fraction
    /// that fall into tight time buckets (similar-photo cluster fodder).
    static func candidates(
        count: Int,
        duplicateFraction: Double = 0.15,
        referenceDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> [SimilarPhotoCandidate] {
        var result: [SimilarPhotoCandidate] = []
        result.reserveCapacity(count)

        let duplicateEvery = duplicateFraction > 0 ? Int(1.0 / duplicateFraction) : Int.max

        for i in 0..<count {
            // Every `duplicateEvery`-th item is an exact duplicate of its
            // predecessor: it must share ALL signature inputs — creation
            // timestamp, dimensions, and size — since DuplicateSignature
            // keys on the rounded creation timestamp too.
            let isDup = i > 0 && i % duplicateEvery == 0
            let sigSeed = isDup ? (i - 1) : i

            // Spread creation dates across ~365 days, clumping every 5th
            // item into the same minute so time-bucketing has real work.
            let dayOffset = TimeInterval(-(sigSeed % 365) * 86_400)
            let minuteClump = TimeInterval((sigSeed / 5) % 60 * 60)
            let creationDate = referenceDate.addingTimeInterval(dayOffset + minuteClump)

            let width = 3000 + (sigSeed % 7) * 100
            let height = 2000 + (sigSeed % 5) * 100
            let size = Int64(1_000_000 + (sigSeed % 11) * 250_000)

            result.append(
                SimilarPhotoCandidate(
                    localIdentifier: "synthetic-\(i)",
                    creationDate: creationDate,
                    pixelWidth: width,
                    pixelHeight: height,
                    estimatedFileSize: size,
                    isFavorite: i % 23 == 0,
                    isHidden: false,
                    isLivePhoto: i % 9 == 0,
                    hasBeenEdited: i % 13 == 0,
                    isInUserAlbum: i % 17 == 0,
                    burstIdentifier: i % 5 == 0 ? "burst-\(i / 5)" : nil
                )
            )
        }
        return result
    }
}
