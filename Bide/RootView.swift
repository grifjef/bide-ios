import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.phase {
        case .onboarding:
            OnboardingView()
                .transition(.opacity)
        case .ready:
            DashboardView()
                .transition(.opacity)
        }
    }
}

#Preview("Onboarding") {
    RootView()
        .environment({
            let s = AppState()
            s.phase = .onboarding
            return s
        }())
        .environment(PhotoLibraryService())
        .environment(ReviewBasket())
}

#Preview("Ready") {
    RootView()
        .environment({
            let s = AppState()
            s.phase = .ready
            return s
        }())
        .environment(PhotoLibraryService())
        .environment(ReviewBasket())
}
