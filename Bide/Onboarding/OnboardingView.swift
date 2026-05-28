import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(DashboardSummary.self) private var dashboardSummary

    @State private var pageIndex: Int = 0
    @State private var isRequestingPermission: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $pageIndex) {
                IntroPage(
                    icon: "leaf.circle.fill",
                    title: "Bide your time",
                    text: "Bide helps you review your camera roll at your pace. Large videos, screenshots, similar shots, and blurry photos — calmly sorted, never auto-deleted."
                )
                .tag(0)

                IntroPage(
                    icon: "lock.shield.fill",
                    title: "Nothing leaves your phone",
                    text: "All analysis happens on this device. No accounts. No ads. No cloud upload by us. No third-party tracking."
                )
                .tag(1)

                IntroPage(
                    icon: "arrow.uturn.backward.circle.fill",
                    title: "Everything is reversible",
                    text: "When you choose to remove something, it goes to Apple's Recently Deleted album where you can restore it for 30 days."
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Action area
            VStack(spacing: BideTheme.m) {
                if pageIndex < 2 {
                    Button {
                        withAnimation {
                            pageIndex += 1
                        }
                    } label: {
                        Text("Continue")
                            .font(BideTheme.cardTitle())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BideTheme.m)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(BideTheme.accent)
                } else {
                    Button {
                        Task { await requestPermissionAndContinue() }
                    } label: {
                        if isRequestingPermission {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BideTheme.m)
                        } else {
                            Text("Give Bide photo access")
                                .font(BideTheme.cardTitle())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BideTheme.m)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(BideTheme.accent)
                    .disabled(isRequestingPermission)

                    Text("Full access lets Bide find clutter across your whole library. You can also choose Limited and pick specific photos.")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BideTheme.m)
                }
            }
            .padding(BideTheme.l)
            .background(BideTheme.background)
        }
        .background(BideTheme.background.ignoresSafeArea())
    }

    private func requestPermissionAndContinue() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let status = await photoLibrary.requestAuthorization()

        // Kick off the dashboard pre-scan the instant we have read access.
        // The scan happens off-main; by the time the user lands on the
        // dashboard a moment later, the module-card subtitles are populated
        // with real counts and reclaim numbers instead of placeholder copy.
        // No-op if denied/restricted.
        if status == .authorized || status == .limited {
            dashboardSummary.refreshIfNeeded()
        }

        // We move forward regardless — if the user denied, the dashboard will
        // show a helpful "permission needed" state and offer Settings.
        switch status {
        case .authorized, .limited, .denied, .restricted, .notDetermined:
            appState.completeOnboarding()
        @unknown default:
            appState.completeOnboarding()
        }
    }
}

private struct IntroPage: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: BideTheme.l) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 88, weight: .light))
                .foregroundStyle(BideTheme.primary)
                .padding(.bottom, BideTheme.m)

            Text(title)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.l)

            Text(text)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
                .padding(.bottom, BideTheme.l)
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    let library = PhotoLibraryService()
    return OnboardingView()
        .environment(AppState())
        .environment(library)
        .environment(DashboardSummary(photoLibrary: library))
}
