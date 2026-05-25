import Foundation
import SwiftData

/// SwiftData container factory. Kept as a pure factory so tests can spin up
/// in-memory containers without dragging in the rest of the app.
enum BideStore {

    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            IndexedAsset.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // We have to crash here — a missing container means the app cannot run.
            // SwiftData itself logs the underlying cause.
            fatalError("Could not create SwiftData container: \(error)")
        }
    }

    @MainActor
    static func makeInMemoryContainer() -> ModelContainer {
        makeContainer(inMemory: true)
    }
}
