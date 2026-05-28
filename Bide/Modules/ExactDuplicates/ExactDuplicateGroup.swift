import Foundation

/// A group of assets that share an identical signature (creation date +
/// dimensions + file size). Unlike a `PhotoCluster` (Similar Photos), these
/// are confirmed identical-or-near-identical and can be safely treated as
/// duplicates with high confidence.
///
/// Why not byte-for-byte? PHAssetResource read of the full image is too
/// expensive for a library scan. The (date, dimensions, size) tuple has a
/// vanishingly low collision rate for genuine non-duplicates — modern HEIC
/// encoders are deterministic, so re-imports of the same photo produce
/// identical bytes and the size tuple matches exactly.
struct ExactDuplicateGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    let signature: DuplicateSignature
    let assets: [SimilarPhotoCandidate]

    /// The canonical keeper — the oldest asset is the "original".
    var keeper: SimilarPhotoCandidate? {
        assets.min { $0.creationDate < $1.creationDate }
    }

    /// All assets except the keeper. These are the safe-to-remove copies.
    var duplicates: [SimilarPhotoCandidate] {
        guard let keeperId = keeper?.id else { return assets }
        return assets.filter { $0.id != keeperId }
    }

    /// Bytes the user could reclaim by removing all non-keeper duplicates.
    var reclaimableBytes: Int64 {
        duplicates.reduce(0) { $0 + $1.estimatedFileSize }
    }

    var formattedReclaim: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }
}

/// Composite key for duplicate detection. Two assets with the same signature
/// are byte-for-byte identical with overwhelming probability.
///
/// We require strict equality on all three fields. iOS HEIC encoding is
/// deterministic, so re-imports of the same image produce identical file
/// sizes; any size difference signals a different source image or a re-encode
/// at different quality, which we treat as non-duplicate (Similar Photos
/// handles those via feature-print similarity).
struct DuplicateSignature: Hashable, Sendable {
    /// Quantized to the second — bursts can fire multiple shots in one second
    /// but those are handled by burst-clustering, not exact-duplicate detection.
    let creationTimestamp: TimeInterval
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64

    init(from candidate: SimilarPhotoCandidate) {
        self.creationTimestamp = candidate.creationDate.timeIntervalSince1970.rounded()
        self.pixelWidth = candidate.pixelWidth
        self.pixelHeight = candidate.pixelHeight
        self.fileSize = candidate.estimatedFileSize
    }
}
