import Foundation
import SwiftData

/// Local index row mirroring (a subset of) PHAsset metadata.
/// We never store image data here — only what's needed to cluster + display.
/// On every launch we reconcile against PhotoKit; entries become stale when
/// the underlying asset is gone.
@Model
final class IndexedAsset {
    @Attribute(.unique) var localIdentifier: String

    var creationDate: Date?
    var modificationDate: Date?

    /// PHAssetMediaType.rawValue (0=unknown, 1=image, 2=video, 3=audio)
    var mediaType: Int

    /// Bitfield of PHAssetMediaSubtype.rawValue
    var mediaSubtypes: Int

    var pixelWidth: Int
    var pixelHeight: Int
    var duration: TimeInterval

    var isFavorite: Bool
    var isHidden: Bool

    /// Best-effort file size in bytes. May be 0 if we haven't sampled this asset yet.
    var estimatedFileSize: Int64

    /// For burst photos (e.g. iPhone burst mode).
    var burstIdentifier: String?

    /// PHAssetSourceType.rawValue
    var sourceType: Int

    /// Last time we ran any analysis on this asset (feature print, etc).
    var lastAnalyzedAt: Date?

    /// 0 = low, 1 = medium, 2 = high. Conservative-default categorization.
    var riskLevelRaw: Int

    /// Cluster grouping (similar photos). Nil if unclustered.
    var clusterIdentifier: UUID?

    /// Serialized `VNFeaturePrintObservation` (via NSSecureCoding).
    /// Coupled with `featurePrintVersion` — if Apple updates the model in a
    /// future iOS, the stored print is stale and we re-cluster.
    var featurePrintData: Data?

    /// Vision's `VNGenerateImageFeaturePrintRequest.currentRevision` at the
    /// time the print was computed. Nil if no print is stored.
    var featurePrintVersion: Int?

    /// Number of characters of text Vision found in this asset's OCR pass.
    /// Used by the Screenshots module to categorize without re-running OCR
    /// on every dashboard visit. We never persist the recognized strings.
    var textCharacterCount: Int?

    /// `ScreenshotCategory.rawValue` if we've classified this asset (only
    /// relevant for screenshot media subtypes). Persisted so the user's
    /// filter chip selection survives app restarts.
    var screenshotCategoryRaw: Int?

    init(
        localIdentifier: String,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        mediaType: Int = 0,
        mediaSubtypes: Int = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        duration: TimeInterval = 0,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        estimatedFileSize: Int64 = 0,
        burstIdentifier: String? = nil,
        sourceType: Int = 0,
        lastAnalyzedAt: Date? = nil,
        riskLevelRaw: Int = 0,
        clusterIdentifier: UUID? = nil,
        featurePrintData: Data? = nil,
        featurePrintVersion: Int? = nil,
        textCharacterCount: Int? = nil,
        screenshotCategoryRaw: Int? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.mediaType = mediaType
        self.mediaSubtypes = mediaSubtypes
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.estimatedFileSize = estimatedFileSize
        self.burstIdentifier = burstIdentifier
        self.sourceType = sourceType
        self.lastAnalyzedAt = lastAnalyzedAt
        self.riskLevelRaw = riskLevelRaw
        self.clusterIdentifier = clusterIdentifier
        self.featurePrintData = featurePrintData
        self.featurePrintVersion = featurePrintVersion
        self.textCharacterCount = textCharacterCount
        self.screenshotCategoryRaw = screenshotCategoryRaw
    }
}

enum RiskLevel: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
}
