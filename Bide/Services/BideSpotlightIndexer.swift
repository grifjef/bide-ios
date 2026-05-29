import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Publishes Bide's modules + "How Bide works" sections to Spotlight so
/// users can search "duplicates" or "screen recordings" from the iOS
/// home screen / Spotlight and land directly inside the app.
///
/// Design notes:
/// - Indexes are content (kCSSearchableItemUTTypeData) per Apple's
///   convention for app destinations.
/// - Each item carries a stable `identifier` we decode in
///   `BideAppDelegate.application(_:continue:restorationHandler:)` and
///   route through the existing `ShortcutAction` pipeline when it maps
///   to a Quick-Action-equivalent destination.
/// - Re-indexing is idempotent — Spotlight dedupes by `uniqueIdentifier`.
///   We re-run the index on each cold launch so copy edits propagate.
@MainActor
enum BideSpotlightIndexer {
    /// Reverse-DNS domain so users can drop us cleanly via
    /// `deleteSearchableItems(withDomainIdentifiers:)` if ever needed.
    static let domain = "com.bidephoto.bide.spotlight"

    /// Activity types Spotlight tags onto results so the
    /// `application(_:continue:restorationHandler:)` path can dispatch.
    enum ActivityType {
        static let openModule = "com.bidephoto.bide.spotlight.openModule"
        static let openHelp   = "com.bidephoto.bide.spotlight.openHelp"
    }

    /// Index every module + the Help page sections. Safe to call repeatedly.
    static func indexAll() {
        var items = moduleItems()
        items.append(contentsOf: helpItems())
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                NSLog("Spotlight indexing failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Module records

    /// One Spotlight result per dashboard module, ordered to match the
    /// dashboard's Quick wins / Bulk review / Careful review groupings.
    private static func moduleItems() -> [CSSearchableItem] {
        ModuleSpotlight.allCases.map { entry in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.content)
            attrs.title = entry.title
            attrs.contentDescription = entry.summary
            attrs.keywords = entry.keywords
            return CSSearchableItem(
                uniqueIdentifier: entry.identifier,
                domainIdentifier: domain,
                attributeSet: attrs
            )
        }
    }

    // MARK: - Help records

    private static func helpItems() -> [CSSearchableItem] {
        HelpSpotlight.allCases.map { entry in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.content)
            attrs.title = entry.title
            attrs.contentDescription = entry.summary
            attrs.keywords = entry.keywords
            return CSSearchableItem(
                uniqueIdentifier: entry.identifier,
                domainIdentifier: domain,
                attributeSet: attrs
            )
        }
    }
}

// MARK: - Module catalog

/// Static catalog of every dashboard module the user can land on. Stable
/// identifiers — renaming a case is a Spotlight cache migration.
enum ModuleSpotlight: String, CaseIterable {
    case findClutter      = "com.bidephoto.bide.spotlight.module.findClutter"
    case exactDuplicates  = "com.bidephoto.bide.spotlight.module.exactDuplicates"
    case screenRecordings = "com.bidephoto.bide.spotlight.module.screenRecordings"
    case largeVideos      = "com.bidephoto.bide.spotlight.module.largeVideos"
    case screenshots      = "com.bidephoto.bide.spotlight.module.screenshots"
    case livePhotos       = "com.bidephoto.bide.spotlight.module.livePhotos"
    case similarPhotos    = "com.bidephoto.bide.spotlight.module.similarPhotos"
    case blurryShots      = "com.bidephoto.bide.spotlight.module.blurryShots"
    case onThisDay        = "com.bidephoto.bide.spotlight.module.onThisDay"
    case reviewBasket     = "com.bidephoto.bide.spotlight.module.reviewBasket"

    var identifier: String { rawValue }

    var title: String {
        switch self {
        case .findClutter:      return "Find clutter — Bide"
        case .exactDuplicates:  return "Exact duplicates — Bide"
        case .screenRecordings: return "Screen recordings — Bide"
        case .largeVideos:      return "Large videos — Bide"
        case .screenshots:      return "Screenshots — Bide"
        case .livePhotos:       return "Live Photos — Bide"
        case .similarPhotos:    return "Similar photos — Bide"
        case .blurryShots:      return "Blurry shots — Bide"
        case .onThisDay:        return "On this day — Bide"
        case .reviewBasket:     return "Review Basket — Bide"
        }
    }

    var summary: String {
        switch self {
        case .findClutter:
            return "Open Bide and scan your camera roll for cleanup candidates."
        case .exactDuplicates:
            return "Byte-for-byte identical photos and videos, found in seconds."
        case .screenRecordings:
            return "The biggest disposable files in most libraries, in one list."
        case .largeVideos:
            return "Sorted by size. Favorites and hidden videos are protected."
        case .screenshots:
            return "Grouped by month and year. Sort by chat / app / visual on demand."
        case .livePhotos:
            return "Convert any Live Photo to a still and reclaim its video sidecar."
        case .similarPhotos:
            return "Time-bucketed clusters with a suggested keeper Bide explains."
        case .blurryShots:
            return "Conservative blur candidates. Photos with faces are excluded."
        case .onThisDay:
            return "Photos from today's calendar day in past years."
        case .reviewBasket:
            return "Confirm or back out of items you've selected."
        }
    }

    var keywords: [String] {
        switch self {
        case .findClutter:
            return ["bide", "clutter", "cleanup", "scan", "photo cleaner"]
        case .exactDuplicates:
            return ["duplicates", "duplicate photos", "copies", "byte for byte"]
        case .screenRecordings:
            return ["screen recordings", "screen capture", "screencast"]
        case .largeVideos:
            return ["large videos", "big videos", "video size", "storage"]
        case .screenshots:
            return ["screenshots", "screen grabs", "captures", "OCR"]
        case .livePhotos:
            return ["live photos", "live photo", "convert", "still", "sidecar"]
        case .similarPhotos:
            return ["similar photos", "near duplicates", "burst", "clusters"]
        case .blurryShots:
            return ["blurry photos", "blurry shots", "blur", "out of focus"]
        case .onThisDay:
            return ["on this day", "memories", "today in years past"]
        case .reviewBasket:
            return ["review basket", "basket", "trash", "confirm"]
        }
    }

    /// Optional translation into the `ShortcutAction` enum so the
    /// continue-user-activity path can reuse the Quick-Action routing
    /// for the three modules already mapped there. Other modules
    /// open the app but don't deep-link to a specific view yet.
    var equivalentShortcut: ShortcutAction? {
        switch self {
        case .findClutter:  return .findClutter
        case .onThisDay:    return .onThisDay
        case .reviewBasket: return .reviewBasket
        default:            return nil
        }
    }
}

// MARK: - Help catalog

enum HelpSpotlight: String, CaseIterable {
    case principles  = "com.bidephoto.bide.spotlight.help.principles"
    case protections = "com.bidephoto.bide.spotlight.help.protections"
    case recovery    = "com.bidephoto.bide.spotlight.help.recovery"
    case privacy     = "com.bidephoto.bide.spotlight.help.privacy"

    var identifier: String { rawValue }

    var title: String {
        switch self {
        case .principles:  return "How decisions work — Bide"
        case .protections: return "What's always protected — Bide"
        case .recovery:    return "If you change your mind — Bide"
        case .privacy:     return "Privacy in one paragraph — Bide"
        }
    }

    var summary: String {
        switch self {
        case .principles:
            return "Bide suggests. You decide. Two confirmations before anything moves."
        case .protections:
            return "Favorites, hidden, faces, albums, and the last 30 days are protected."
        case .recovery:
            return "Every removal goes to Apple's Recently Deleted album for 30 days."
        case .privacy:
            return "No accounts, no ads, no third-party SDKs, no photos uploaded."
        }
    }

    var keywords: [String] {
        switch self {
        case .principles:  return ["how", "decisions", "confirmations", "review basket"]
        case .protections: return ["protected", "favorites", "hidden", "faces", "albums"]
        case .recovery:    return ["recover", "undo", "recently deleted", "restore"]
        case .privacy:     return ["privacy", "no tracking", "on device", "no ads"]
        }
    }
}
