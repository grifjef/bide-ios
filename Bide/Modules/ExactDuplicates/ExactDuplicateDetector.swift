import Foundation
import os

/// Pure signature-based duplicate detection. Groups assets that share the same
/// `DuplicateSignature` (creation timestamp + dimensions + size bucket) and
/// returns only the groups that have ≥ 2 members.
///
/// This is dramatically faster than feature-print similarity clustering —
/// no Vision, no thumbnails, just a single dictionary pass.
enum ExactDuplicateDetector {

    /// Returns groups of size ≥ 2, sorted by total reclaimable bytes descending
    /// (most space-saving groups first).
    static func detect(_ candidates: [SimilarPhotoCandidate]) -> [ExactDuplicateGroup] {
        let id = BideSignposts.scansSignposter.makeSignpostID()
        let state = BideSignposts.scansSignposter.beginInterval(
            "exactDuplicates.detect",
            id: id,
            "candidates=\(candidates.count, privacy: .public)"
        )
        defer {
            BideSignposts.scansSignposter.endInterval("exactDuplicates.detect", state)
        }
        var bySignature: [DuplicateSignature: [SimilarPhotoCandidate]] = [:]
        for candidate in candidates {
            // Skip protected items entirely. We never want to suggest deleting
            // a favorited or hidden photo, even if it has duplicates.
            if candidate.isFavorite || candidate.isHidden { continue }
            let sig = DuplicateSignature(from: candidate)
            bySignature[sig, default: []].append(candidate)
        }

        let groups = bySignature
            .filter { $0.value.count >= 2 }
            .map { signature, assets -> ExactDuplicateGroup in
                ExactDuplicateGroup(
                    id: UUID(),
                    signature: signature,
                    assets: assets.sorted { $0.creationDate < $1.creationDate }
                )
            }
            .sorted { $0.reclaimableBytes > $1.reclaimableBytes }

        return groups
    }

    /// Summary statistics for a dashboard headline.
    static func summary(_ groups: [ExactDuplicateGroup]) -> (groupCount: Int, duplicateCount: Int, reclaimableBytes: Int64) {
        let duplicateCount = groups.reduce(0) { $0 + $1.duplicates.count }
        let reclaimableBytes = groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        return (groups.count, duplicateCount, reclaimableBytes)
    }
}
