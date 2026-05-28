import SwiftUI
import SwiftData

@main
struct BideApp: App {
    @State private var appState = AppState()
    @State private var photoLibrary: PhotoLibraryService
    @State private var reviewBasket = ReviewBasket()
    @State private var dashboardSummary: DashboardSummary
    @State private var metrics = MetricsService()
    @State private var backgroundRefresh: BackgroundRefreshService

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer = BideStore.makeContainer()

    init() {
        let library = PhotoLibraryService()
        let summary = DashboardSummary(photoLibrary: library)
        _photoLibrary = State(initialValue: library)
        _dashboardSummary = State(initialValue: summary)

        let bgService = BackgroundRefreshService(
            summary: summary,
            photoLibrary: library
        )
        _backgroundRefresh = State(initialValue: bgService)

        // BGTaskScheduler.register MUST be called before the app finishes
        // launching. Doing it inside the App.init keeps the order
        // guaranteed regardless of how SwiftUI sequences the body.
        MainActor.assumeIsolated {
            bgService.registerTaskHandler()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(photoLibrary)
                .environment(reviewBasket)
                .environment(dashboardSummary)
                .environment(metrics)
                .modelContainer(modelContainer)
                .tint(BideTheme.accent)
                .preferredColorScheme(nil) // respect system setting
                .task {
                    // Subscribe to MetricKit deliveries. iOS posts payloads
                    // once per day on app launch — we persist them locally
                    // for the Diagnostics screen.
                    metrics.subscribeToMetricKit()
                }
        }
        .onChange(of: scenePhase) { _, new in
            switch new {
            case .active:
                // When the app returns to the foreground, re-read PhotoKit auth.
                // The user may have flipped permission in Settings while we were
                // backgrounded; we want the dashboard's "Photo access needed"
                // banner to disappear immediately.
                photoLibrary.refreshAuthStatus()
                dashboardSummary.refreshIfNeeded()
            case .background:
                // Submit the next BG refresh request. iOS only honors the
                // request after the app actually backgrounds, so this is
                // the right hook — not `.inactive`, which can fire on
                // notification banners and similar transient blurs.
                backgroundRefresh.scheduleNext()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
