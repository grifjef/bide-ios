import SwiftUI
import SwiftData

@main
struct BideApp: App {
    @State private var appState = AppState()
    @State private var photoLibrary = PhotoLibraryService()
    @State private var reviewBasket = ReviewBasket()

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = BideStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(photoLibrary)
                .environment(reviewBasket)
                .modelContainer(modelContainer)
                .tint(BideTheme.accent)
                .preferredColorScheme(nil) // respect system setting
        }
        .onChange(of: scenePhase) { _, new in
            // When the app returns to the foreground, re-read PhotoKit auth.
            // The user may have flipped permission in Settings while we were
            // backgrounded; we want the dashboard's "Photo access needed"
            // banner to disappear immediately.
            if new == .active {
                photoLibrary.refreshAuthStatus()
            }
        }
    }
}
