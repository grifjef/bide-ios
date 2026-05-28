import Foundation

/// Lightweight value type for large-video review. Doesn't carry PHAsset reference
/// so it's Sendable and free to pass across actor boundaries / SwiftUI views.
struct LargeVideoSummary: Identifiable, Hashable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let duration: TimeInterval
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64
    let isFavorite: Bool
    let isHidden: Bool
    let sourceTypeIsCamera: Bool
    let isScreenRecording: Bool

    var id: String { localIdentifier }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var formattedDate: String {
        guard let date = creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// True if this video is protected by our conservative defaults
    /// (favorites and hidden items are never auto-selectable).
    var isProtected: Bool {
        isFavorite || isHidden
    }
}

/// Lightweight value type for Live Photo review.
struct LivePhotoSummary: Identifiable, Hashable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64
    let isFavorite: Bool
    let isHidden: Bool

    var id: String { localIdentifier }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        guard let date = creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var isProtected: Bool {
        isFavorite || isHidden
    }
}

struct ScreenshotSummary: Identifiable, Hashable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isHidden: Bool

    var id: String { localIdentifier }

    var formattedDate: String {
        guard let date = creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var isProtected: Bool {
        isFavorite || isHidden
    }
}
