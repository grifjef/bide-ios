import SwiftUI
import SwiftData

@main
struct BideApp: App {
    @State private var appState = AppState()
    @State private var photoLibrary = PhotoLibraryService()
    @State private var reviewBasket = ReviewBasket()

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
    }
}
