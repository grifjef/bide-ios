import Foundation

/// Value type representing a single candidate in the similar-photo clustering pipeline.
/// Carries everything we need for keeper-scoring decisions — no PHAsset reference
/// so it's Sendable and pure-testable.
struct SimilarPhotoCandidate: Identifiable, Hashable, Sendable {
    let localIdentifier: String
    let creationDate: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let estimatedFileSize: Int64
    let isFavorite: Bool
    let isHidden: Bool
    let isLivePhoto: Bool
    let hasBeenEdited: Bool
    let isInUserAlbum: Bool

    /// PHAsset.burstIdentifier — non-nil when this asset is part of a burst
    /// sequence. Bursts are handled by direct grouping in the scan service
    /// (much faster than Vision clustering) so we don't need to feature-print
    /// them.
    let burstIdentifier: String?

    var id: String { localIdentifier }

    var resolution: Int { pixelWidth * pixelHeight }

    /// Items in these categories should not be auto-suggested for deletion
    /// even if they're in a cluster. The keeper-selection logic uses these
    /// signals as preference, not as exclusion.
    var hasProtectedSignal: Bool {
        isFavorite || isHidden || isInUserAlbum
    }
}

/// A group of similar photos with one suggested keeper. The user is shown
/// the cluster, the suggested keeper is pre-highlighted (but never pre-added
/// to the basket), and the user explicitly chooses what to keep.
struct PhotoCluster: Identifiable, Hashable, Sendable {
    let id: UUID
    let representativeDate: Date
    let candidates: [SimilarPhotoCandidate]
    let suggestedKeeperId: String
    let suggestedKeeperReason: String

    /// All candidates except the suggested keeper. These are the items the user
    /// might (deliberately) move to the Review Basket.
    var nonKeeperCandidates: [SimilarPhotoCandidate] {
        candidates.filter { $0.id != suggestedKeeperId }
    }

    var suggestedKeeper: SimilarPhotoCandidate? {
        candidates.first { $0.id == suggestedKeeperId }
    }

    /// Sum of estimated bytes that *could* be reclaimed if every non-keeper
    /// was added to the basket. Not auto-selected — just shown as a hint.
    var potentialReclaimBytes: Int64 {
        nonKeeperCandidates.reduce(0) { $0 + $1.estimatedFileSize }
    }

    var formattedPotentialReclaim: String {
        ByteCountFormatter.string(fromByteCount: potentialReclaimBytes, countStyle: .file)
    }
}
