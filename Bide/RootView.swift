import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Opacity fade is the gentlest transition in SwiftUI's catalog, but
        // even that gets suppressed when the user has Reduce Motion on. We
        // identity-transition in that case — instant swap, no animation.
        Group {
            switch appState.phase {
            case .onboarding:
                OnboardingView()
            case .ready:
                DashboardView()
            }
        }
        .transition(reduceMotion ? .identity : .opacity)
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
