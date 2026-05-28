import Foundation
import Observation

/// The trust center: a local-only collection of items the user has marked
/// for removal across modules. Nothing deletes until the user confirms.
@Observable
@MainActor
final class ReviewBasket {
    enum Source: String, CaseIterable, Sendable {
        case largeVideos
        case screenRecordings
        case screenshots
        case livePhotos
        case similar
        case blurry
        case exactDuplicates
        case onThisDay

        var displayName: String {
            switch self {
            case .largeVideos: return "Large videos"
            case .screenRecordings: return "Screen recordings"
            case .screenshots: return "Screenshots"
            case .livePhotos: return "Live Photos"
            case .similar: return "Similar photos"
            case .blurry: return "Blurry shots"
            case .exactDuplicates: return "Exact duplicates"
            case .onThisDay: return "On this day"
            }
        }
    }

    struct Item: Identifiable, Hashable {
        let id: String
        let source: Source
        let estimatedBytes: Int64
        let displayDate: String?

        init(localIdentifier: String, source: Source, estimatedBytes: Int64, displayDate: String? = nil) {
            self.id = localIdentifier
            self.source = source
            self.estimatedBytes = estimatedBytes
            self.displayDate = displayDate
        }
    }

    private(set) var items: [Item] = []

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.estimatedBytes }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    func contains(localIdentifier: String) -> Bool {
        items.contains(where: { $0.id == localIdentifier })
    }

    func add(_ item: Item) {
        guard !contains(localIdentifier: item.id) else { return }
        items.append(item)
    }

    func remove(localIdentifier: String) {
        items.removeAll { $0.id == localIdentifier }
    }

    func clear() {
        items.removeAll()
    }

    func items(from source: Source) -> [Item] {
        items.filter { $0.source == source }
    }

    func toggle(_ item: Item) {
        if contains(localIdentifier: item.id) {
            remove(localIdentifier: item.id)
        } else {
            add(item)
        }
    }
}
