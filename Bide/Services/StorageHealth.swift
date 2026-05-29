import Foundation

/// Pulls the device's free / total storage capacity for the volume Bide
/// runs on. Pure function over `URLResourceValues` — no PhotoKit, no
/// MainActor, fully testable with an injectable URL.
///
/// Keys we ask for:
///   - `.volumeAvailableCapacityForImportantUsageKey` — the iOS-flavored
///     "how much can the app actually use right now" reading. Accounts
///     for offload-able iCloud assets, the system's headroom, etc. This
///     is the number Settings → General → iPhone Storage shows as
///     "Available."
///   - `.volumeTotalCapacityKey` — denominator. Fixed per device.
enum StorageHealth {

    struct Snapshot: Equatable, Sendable {
        let freeBytes: Int64
        let totalBytes: Int64

        var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
        var freeFraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(freeBytes) / Double(totalBytes)
        }

        var formattedFree: String {
            ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
        }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    /// Synchronous read. iOS caches these values so the call is cheap; we
    /// still call it off the main path on first dashboard appear out of
    /// habit, but the cost is negligible.
    static func snapshot(at url: URL = .documentsDirectory) -> Snapshot? {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return nil
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0

        guard total > 0, free >= 0 else { return nil }
        return Snapshot(freeBytes: free, totalBytes: total)
    }
}

private extension URL {
    /// Documents directory of the app — same volume as everything else.
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
    }
}
