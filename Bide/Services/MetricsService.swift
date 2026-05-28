import Foundation
import MetricKit
import Observation

/// Subscriber for Apple's MetricKit deliveries. iOS sends `MXMetricPayload`
/// (performance metrics) and `MXDiagnosticPayload` (crashes, hangs, disk
/// writes, etc.) once per day on app launch.
///
/// Bide persists them as JSON files in Application Support and surfaces
/// them in the Diagnostics screen. **Nothing is transmitted anywhere** —
/// this is the user's own data, kept on their device, and they can see
/// exactly what iOS is reporting about Bide's behavior.
///
/// The privacy boundary: MetricKit payloads contain CPU, memory, disk,
/// network, animation, and crash stats *for our app*. They never contain
/// user content (no photos, no asset identifiers). We don't strip them
/// because they were never identifying to begin with.
@Observable
@MainActor
final class MetricsService: NSObject, MXMetricManagerSubscriber {
    /// Capped at 30 days — MetricKit itself sends 24 hours of data per
    /// payload, and 30 days is plenty of context for debugging while
    /// keeping disk usage trivial.
    static let retentionDays: Int = 30

    /// Most recent payloads first.
    private(set) var diagnostics: [StoredPayload] = []

    /// Directory where we persist payloads. Subfolder of Application Support
    /// so it doesn't end up in iCloud backups by default.
    private let directory: URL

    override init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = appSupport.appendingPathComponent("MetricKit", isDirectory: true)
        super.init()
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        loadStored()
    }

    /// Register as MetricKit subscriber. Idempotent — calling twice from
    /// scenePhase changes is safe; MetricKit deduplicates.
    func subscribeToMetricKit() {
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        Task { @MainActor in
            for payload in payloads {
                self.persist(metric: payload)
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Task { @MainActor in
            for payload in payloads {
                self.persist(diagnostic: payload)
            }
        }
    }

    // MARK: - Persistence

    private func persist(metric payload: MXMetricPayload) {
        let data = payload.jsonRepresentation()
        let url = nextURL(prefix: "metric")
        try? data.write(to: url, options: .atomic)
        loadStored()
    }

    private func persist(diagnostic payload: MXDiagnosticPayload) {
        let data = payload.jsonRepresentation()
        let url = nextURL(prefix: "diag")
        try? data.write(to: url, options: .atomic)
        loadStored()
    }

    private func nextURL(prefix: String) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "\(prefix)-\(stamp).json"
        return directory.appendingPathComponent(filename)
    }

    private func loadStored() {
        let fm = FileManager.default
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: Date()) ?? Date.distantPast
        guard let urls = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            diagnostics = []
            return
        }

        var payloads: [StoredPayload] = []
        payloads.reserveCapacity(urls.count)
        for url in urls {
            let attributes = (try? url.resourceValues(forKeys: [.creationDateKey])) ?? URLResourceValues()
            let created = attributes.creationDate ?? Date.distantPast

            // Prune older-than-retention as we go.
            if created < cutoff {
                try? fm.removeItem(at: url)
                continue
            }

            let kind: PayloadKind = url.lastPathComponent.hasPrefix("diag")
                ? .diagnostic
                : .metric
            payloads.append(
                StoredPayload(
                    id: url.lastPathComponent,
                    kind: kind,
                    capturedAt: created,
                    fileURL: url
                )
            )
        }
        diagnostics = payloads.sorted { $0.capturedAt > $1.capturedAt }
    }

    // MARK: - Read accessors

    func readJSON(_ payload: StoredPayload) -> String {
        guard let data = try? Data(contentsOf: payload.fileURL) else {
            return "(no data)"
        }
        // Pretty-print if it parses; fall back to raw string if it doesn't.
        if let object = try? JSONSerialization.jsonObject(with: data, options: []),
           let pretty = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
           ),
           let asString = String(data: pretty, encoding: .utf8) {
            return asString
        }
        return String(data: data, encoding: .utf8) ?? "(non-text payload)"
    }

    func deleteAll() {
        let fm = FileManager.default
        for payload in diagnostics {
            try? fm.removeItem(at: payload.fileURL)
        }
        diagnostics = []
    }

    // MARK: - Types

    enum PayloadKind: String, Sendable {
        case metric
        case diagnostic

        var displayName: String {
            switch self {
            case .metric: return "Performance metrics"
            case .diagnostic: return "Diagnostic (crash / hang / etc.)"
            }
        }

        var iconName: String {
            switch self {
            case .metric: return "speedometer"
            case .diagnostic: return "exclamationmark.bubble"
            }
        }
    }

    struct StoredPayload: Identifiable, Sendable, Hashable {
        let id: String
        let kind: PayloadKind
        let capturedAt: Date
        let fileURL: URL

        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: capturedAt)
        }
    }
}
