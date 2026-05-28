import Foundation
import SwiftData
import Vision

/// Persistence layer for `IndexedAsset` — the local index that lets repeat
/// scans skip recomputing feature prints.
///
/// **Boundaries:**
///   - Stays on the main actor because SwiftData's `ModelContext` is main-actor.
///   - Owns the upsert/reconcile semantics so callers (the scan services) don't
///     touch SwiftData directly.
///   - Throws on persistence failures so callers can decide whether to abort
///     or continue scanning without persistence.
///
/// **Reconciliation:** PhotoKit can delete assets while we're using them.
/// `reconcile(against:)` drops indexed entries whose `localIdentifier` is no
/// longer in the present set. Called at the start of each scan.
@MainActor
final class IndexedAssetStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetch(localIdentifier: String) throws -> IndexedAsset? {
        let descriptor = FetchDescriptor<IndexedAsset>(
            predicate: #Predicate { $0.localIdentifier == localIdentifier }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchAll() throws -> [IndexedAsset] {
        try modelContext.fetch(FetchDescriptor<IndexedAsset>())
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<IndexedAsset>())
    }

    // MARK: - Reads (feature-print specific)

    /// Returns the raw stored feature-print bytes for `localIdentifier` only if
    /// the version matches `requiredVersion`. Tests use this so they don't have
    /// to call into Vision for decoding.
    func storedFeaturePrintData(
        for localIdentifier: String,
        requiredVersion: Int
    ) throws -> Data? {
        guard let asset = try fetch(localIdentifier: localIdentifier) else {
            return nil
        }
        guard asset.featurePrintVersion == requiredVersion else {
            return nil
        }
        return asset.featurePrintData
    }

    /// Convenience that decodes the stored bytes into a `VNFeaturePrintObservation`.
    /// Returns nil if no print is stored, the version is stale, or decoding fails.
    func storedFeaturePrint(
        for localIdentifier: String,
        requiredVersion: Int
    ) throws -> VNFeaturePrintObservation? {
        guard let data = try storedFeaturePrintData(
            for: localIdentifier,
            requiredVersion: requiredVersion
        ) else { return nil }
        return FeaturePrintCoder.decode(data)
    }

    // MARK: - Writes

    /// Upsert with a pre-encoded feature-print payload. Vision-agnostic — the
    /// store doesn't care how the bytes were produced, only that they pair with
    /// a `version` for staleness checks. Tests use this directly so they don't
    /// have to spin up Vision's neural engine context (which fails in some
    /// Simulator configurations).
    @discardableResult
    func upsertFeaturePrint(
        for candidate: SimilarPhotoCandidate,
        featurePrintData: Data,
        version: Int,
        analyzedAt: Date = Date()
    ) throws -> IndexedAsset {
        if let existing = try fetch(localIdentifier: candidate.localIdentifier) {
            existing.featurePrintData = featurePrintData
            existing.featurePrintVersion = version
            existing.lastAnalyzedAt = analyzedAt
            applyMetadata(candidate, to: existing)
            try modelContext.save()
            return existing
        }

        let new = IndexedAsset(
            localIdentifier: candidate.localIdentifier,
            creationDate: candidate.creationDate,
            mediaType: 1, // image
            pixelWidth: candidate.pixelWidth,
            pixelHeight: candidate.pixelHeight,
            duration: 0,
            isFavorite: candidate.isFavorite,
            isHidden: candidate.isHidden,
            estimatedFileSize: candidate.estimatedFileSize,
            lastAnalyzedAt: analyzedAt,
            featurePrintData: featurePrintData,
            featurePrintVersion: version
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    /// Convenience upsert that encodes a `VNFeaturePrintObservation` first.
    /// This is what production code (scan services) calls.
    @discardableResult
    func upsertFeaturePrint(
        for candidate: SimilarPhotoCandidate,
        featurePrint: VNFeaturePrintObservation,
        version: Int,
        analyzedAt: Date = Date()
    ) throws -> IndexedAsset {
        guard let data = FeaturePrintCoder.encode(featurePrint) else {
            throw StoreError.encodingFailed
        }
        return try upsertFeaturePrint(
            for: candidate,
            featurePrintData: data,
            version: version,
            analyzedAt: analyzedAt
        )
    }

    // MARK: - Screenshot category persistence

    /// Persist the OCR character count + classified category for a screenshot.
    /// Creates the IndexedAsset if it doesn't exist yet. Doesn't touch any
    /// feature-print fields — those live on the same row but are independent.
    @discardableResult
    func upsertScreenshotCategory(
        localIdentifier: String,
        textCharacterCount: Int,
        category: ScreenshotCategory,
        analyzedAt: Date = Date()
    ) throws -> IndexedAsset {
        if let existing = try fetch(localIdentifier: localIdentifier) {
            existing.textCharacterCount = textCharacterCount
            existing.screenshotCategoryRaw = category.rawValue
            existing.lastAnalyzedAt = analyzedAt
            try modelContext.save()
            return existing
        }
        let new = IndexedAsset(
            localIdentifier: localIdentifier,
            mediaType: 1, // image
            lastAnalyzedAt: analyzedAt,
            textCharacterCount: textCharacterCount,
            screenshotCategoryRaw: category.rawValue
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    /// Return the stored category for a screenshot, or nil if we haven't
    /// classified it yet (or the row exists but has no category).
    func storedScreenshotCategory(for localIdentifier: String) throws -> ScreenshotCategory? {
        guard let asset = try fetch(localIdentifier: localIdentifier),
              let raw = asset.screenshotCategoryRaw,
              let category = ScreenshotCategory(rawValue: raw)
        else { return nil }
        return category
    }

    // MARK: - Reconciliation

    /// Drop indexed entries whose `localIdentifier` isn't in `presentIdentifiers`.
    /// Returns the number of entries removed. Saves once after all deletions.
    @discardableResult
    func reconcile(against presentIdentifiers: Set<String>) throws -> Int {
        let all = try fetchAll()
        var dropped = 0
        for asset in all where !presentIdentifiers.contains(asset.localIdentifier) {
            modelContext.delete(asset)
            dropped += 1
        }
        if dropped > 0 {
            try modelContext.save()
        }
        return dropped
    }

    /// Wipe the entire index. For tests and debug-menu "reset" actions.
    func deleteAll() throws {
        let all = try fetchAll()
        for asset in all {
            modelContext.delete(asset)
        }
        try modelContext.save()
    }

    // MARK: - Internals

    /// Copy the mutable metadata from a `SimilarPhotoCandidate` into an
    /// existing `IndexedAsset`. The candidate is the source of truth for
    /// anything PhotoKit might have changed since we last saw the asset.
    private func applyMetadata(_ candidate: SimilarPhotoCandidate, to asset: IndexedAsset) {
        asset.creationDate = candidate.creationDate
        asset.pixelWidth = candidate.pixelWidth
        asset.pixelHeight = candidate.pixelHeight
        asset.isFavorite = candidate.isFavorite
        asset.isHidden = candidate.isHidden
        asset.estimatedFileSize = candidate.estimatedFileSize
    }

    enum StoreError: Error, Equatable {
        case encodingFailed
    }
}
