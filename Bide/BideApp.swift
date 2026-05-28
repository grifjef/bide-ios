import SwiftUI
import SwiftData

@main
struct BideApp: App {
    @State private var appState = AppState()
    @State private var photoLibrary: PhotoLibraryService
    @State private var reviewBasket = ReviewBasket()
    @State private var dashboardSummary: DashboardSummary

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = BideStore.makeContainer()

    init() {
        let library = PhotoLibraryService()
        _photoLibrary = State(initialValue: library)
        _dashboardSummary = State(initialValue: DashboardSummary(photoLibrary: library))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(photoLibrary)
                .environment(reviewBasket)
                .environment(dashboardSummary)
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
                dashboardSummary.refreshIfNeeded()
            }
        }
    }
}
