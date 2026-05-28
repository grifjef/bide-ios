import SwiftUI
import Photos

struct DashboardView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @Environment(DashboardSummary.self) private var summary

    @State private var showReviewBasket: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BideTheme.m) {
                    // Permission state banner
                    if !photoLibrary.hasReadAccess {
                        permissionBanner
                    } else if photoLibrary.authStatus == .limited {
                        LimitedLibraryBanner()
                    }

                    // Module cards
                    VStack(spacing: BideTheme.m) {
                        NavigationLink {
                            ExactDuplicatesView()
                        } label: {
                            ModuleCard(
                                icon: "doc.on.doc.fill",
                                title: "Exact duplicates",
                                subtitle: duplicatesSubtitle,
                                disabled: !photoLibrary.hasReadAccess,
                                badge: "Beta"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)

                        NavigationLink {
                            ScreenRecordingsView()
                        } label: {
                            ModuleCard(
                                icon: "record.circle.fill",
                                title: "Screen recordings",
                                subtitle: screenRecordingsSubtitle,
                                disabled: !photoLibrary.hasReadAccess,
                                badge: "Beta"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)

                        NavigationLink {
                            LargeVideosView()
                        } label: {
                            ModuleCard(
                                icon: "video.circle.fill",
                                title: "Large videos",
                                subtitle: largeVideosSubtitle,
                                disabled: !photoLibrary.hasReadAccess
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)

                        NavigationLink {
                            ScreenshotsView()
                        } label: {
                            ModuleCard(
                                icon: "doc.on.doc",
                                title: "Screenshots",
                                subtitle: screenshotsSubtitle,
                                disabled: !photoLibrary.hasReadAccess
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)

                        NavigationLink {
                            SimilarPhotosView()
                        } label: {
                            ModuleCard(
                                icon: "square.on.square.dashed",
                                title: "Similar photos",
                                subtitle: "Clusters of near-duplicates with a suggested keeper.",
                                disabled: !photoLibrary.hasReadAccess,
                                badge: "Beta"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)

                        NavigationLink {
                            BlurryShotsView()
                        } label: {
                            ModuleCard(
                                icon: "scribble.variable",
                                title: "Blurry shots",
                                subtitle: "Candidates only — never auto-suggested.",
                                disabled: !photoLibrary.hasReadAccess,
                                badge: "Beta"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!photoLibrary.hasReadAccess)
                    }
                }
                .padding(BideTheme.m)
            }
            .background(BideTheme.background)
            .navigationTitle("Bide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings and privacy")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !basket.isEmpty {
                    reviewBasketBar
                }
            }
            .navigationDestination(isPresented: $showReviewBasket) {
                ReviewBasketView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                // Kick off (or refresh) the dashboard summary on first appear.
                // No-op if we already ran in this session via scenePhase.
                summary.refreshIfNeeded()
            }
            .refreshable {
                summary.refreshIfNeeded()
                while summary.isRefreshing {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }

    // MARK: - Dynamic subtitles

    private var duplicatesSubtitle: String {
        if let s = summary.duplicates {
            if s.duplicateCount == 0 {
                return "No duplicates found."
            }
            return "\(s.duplicateCount) duplicate\(s.duplicateCount == 1 ? "" : "s") · \(s.formattedReclaim) reclaimable"
        }
        return "Byte-for-byte identical copies. Fast and safe."
    }

    private var largeVideosSubtitle: String {
        if let s = summary.largeVideos {
            if s.count == 0 {
                return "No large videos found."
            }
            return "\(s.count) video\(s.count == 1 ? "" : "s") · \(s.formattedTotal)"
        }
        return "Find the biggest files first."
    }

    private var screenRecordingsSubtitle: String {
        if let s = summary.screenRecordings {
            if s.count == 0 {
                return "No screen recordings found."
            }
            return "\(s.count) recording\(s.count == 1 ? "" : "s") · \(s.formattedTotal)"
        }
        return "One-time-use captures, easy to clear."
    }

    private var screenshotsSubtitle: String {
        if let s = summary.screenshots {
            if s.count == 0 {
                return "No screenshots found."
            }
            return "\(s.count) screenshot\(s.count == 1 ? "" : "s") · ~\(s.formattedTotal)"
        }
        return "Group and review old screenshots."
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(BideTheme.warning)
                Text("Photo access needed")
                    .font(BideTheme.cardTitle())
            }
            Text("Bide can't find clutter without permission to read your photo library. Nothing is uploaded.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(BideTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private var reviewBasketBar: some View {
        Button {
            showReviewBasket = true
        } label: {
            HStack(spacing: BideTheme.m) {
                Image(systemName: "tray.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review basket")
                        .font(BideTheme.cardTitle())
                    Text("\(basket.count) item\(basket.count == 1 ? "" : "s") · \(basket.formattedTotalSize)")
                        .font(BideTheme.caption())
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(BideTheme.m)
            .background(BideTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))
            .padding(BideTheme.m)
        }
        .accessibilityLabel("Open Review Basket. \(basket.count) item\(basket.count == 1 ? "" : "s"), \(basket.formattedTotalSize) total.")
        .accessibilityHint("Double-tap to review and confirm before moving items to Recently Deleted.")
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(PhotoLibraryService())
        .environment(ReviewBasket())
}
