import Foundation
import SwiftData
import WidgetKit

/// CRUD for `ReclaimSession` plus the small aggregates the UI needs (lifetime
/// totals, recent sessions). Like `IndexedAssetStore`, this is the only thing
/// that touches `ModelContext` directly so the rest of the app stays out of
/// SwiftData.
@MainActor
final class ReclaimHistoryStore {
    /// Pre-computed aggregate for display.
    struct LifetimeTotals: Equatable {
        let sessionCount: Int
        let itemCount: Int
        let bytes: Int64
        let firstSessionAt: Date?

        var formattedBytes: String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        static let zero = LifetimeTotals(
            sessionCount: 0,
            itemCount: 0,
            bytes: 0,
            firstSessionAt: nil
        )
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Writes

    @discardableResult
    func record(
        itemCount: Int,
        bytesReclaimed: Int64,
        completedAt: Date = Date()
    ) throws -> ReclaimSession {
        let session = ReclaimSession(
            completedAt: completedAt,
            itemCount: itemCount,
            bytesReclaimed: bytesReclaimed
        )
        modelContext.insert(session)
        try modelContext.save()

        // Mirror the new lifetime totals into the App Group store and ask
        // WidgetKit to reload, so the Home Screen / Lock Screen widgets
        // reflect this session without waiting for the next hourly refresh.
        // Both calls are best-effort — a widget that lags one update is
        // never worth failing the delete path over.
        publishWidgetSnapshot()
        return session
    }

    /// Recompute lifetime totals and push them to the widget's shared
    /// store. Called after every `record`. Reads are cheap (session count
    /// is small) and this keeps the widget single-sourced from SwiftData.
    private func publishWidgetSnapshot() {
        guard let totals = try? lifetimeTotals() else { return }
        let lastAt = (try? fetchAll())?.first?.completedAt
        WidgetSharedStore.write(
            WidgetSharedData(
                lifetimeBytes: totals.bytes,
                sessionCount: totals.sessionCount,
                itemCount: totals.itemCount,
                lastSessionAt: lastAt
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Reads

    func fetchAll() throws -> [ReclaimSession] {
        let descriptor = FetchDescriptor<ReclaimSession>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func count() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<ReclaimSession>())
    }

    func lifetimeTotals() throws -> LifetimeTotals {
        let all = try fetchAll()
        guard !all.isEmpty else { return .zero }
        let totalItems = all.reduce(0) { $0 + $1.itemCount }
        let totalBytes = all.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        let earliest = all.map(\.completedAt).min()
        return LifetimeTotals(
            sessionCount: all.count,
            itemCount: totalItems,
            bytes: totalBytes,
            firstSessionAt: earliest
        )
    }

    func deleteAll() throws {
        for session in try fetchAll() {
            modelContext.delete(session)
        }
        try modelContext.save()
    }
}
