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

                    // On This Day callout — only shown when there are
                    // photos from this day in past years
                    if let s = summary.onThisDay, s.totalCount > 0 {
                        NavigationLink {
                            OnThisDayView()
                        } label: {
                            onThisDayCard(s)
                        }
                        .buttonStyle(.plain)
                    }

                    // Sectioned module groups
                    quickWinsSection
                    cleanupSection
                    memoryReviewSection

                    freshnessPill
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

    // MARK: - Sections

    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            sectionHeader(title: "Quick wins", subtitle: "Fast, safe, high-confidence cleanup")

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
        }
    }

    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            sectionHeader(title: "Bulk review", subtitle: "Older clutter, organized for quick decisions")

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
                LivePhotosView()
            } label: {
                ModuleCard(
                    icon: "livephoto",
                    title: "Live Photos",
                    subtitle: livePhotosSubtitle,
                    disabled: !photoLibrary.hasReadAccess,
                    badge: "Beta"
                )
            }
            .buttonStyle(.plain)
            .disabled(!photoLibrary.hasReadAccess)
        }
    }

    private var memoryReviewSection: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            sectionHeader(
                title: "Careful review",
                subtitle: "Close looks where false positives would hurt"
            )

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

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(BideTheme.cardTitle())
            Text(subtitle)
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, BideTheme.s)
        .padding(.horizontal, BideTheme.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func onThisDayCard(_ s: DashboardSummary.OnThisDayCount) -> some View {
        let yearsAgoLabel = s.yearsAgo == 1 ? "1 year ago" : "\(s.yearsAgo) years ago"
        return VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack(spacing: BideTheme.s) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(BideTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("On this day")
                        .font(BideTheme.cardTitle())
                    Text("\(s.totalCount) photo\(s.totalCount == 1 ? "" : "s"), starting \(yearsAgoLabel)")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BideTheme.textTertiary)
            }
            Text("A calm five-minute look back at the same calendar day from past years. No pressure to delete — just review.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("On this day. \(s.totalCount) photos from past years on this calendar day.")
        .accessibilityHint("Double-tap to review photos from past years")
    }

    private var livePhotosSubtitle: String {
        if let s = summary.livePhotos {
            if s.count == 0 {
                return "No Live Photos found."
            }
            return "\(s.count) Live Photo\(s.count == 1 ? "" : "s") · \(s.formattedTotal)"
        }
        return "Stills with a short video sidecar."
    }

    /// Subtle pill at the bottom of the dashboard reporting scan freshness.
    /// Shows "Refreshing…" while a scan is in flight (including the auto-
    /// triggered post-library-change scan) and "Updated N min ago" when
    /// quiet. Designed to be reassuring without being noisy — small font,
    /// muted color, no animation. Hidden entirely when there's nothing to
    /// say (pre-scan).
    @ViewBuilder
    private var freshnessPill: some View {
        if summary.isRefreshing {
            HStack(spacing: BideTheme.xs) {
                ProgressView().controlSize(.mini)
                Text("Refreshing scans…")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, BideTheme.s)
            .accessibilityLabel("Bide is refreshing the dashboard scans.")
        } else if let at = summary.lastRefreshAt {
            Text("Updated \(Self.freshnessFormatter.localizedString(for: at, relativeTo: Date()))")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, BideTheme.s)
                .accessibilityLabel("Dashboard last updated \(Self.accessibleFormatter.string(from: at)).")
        } else {
            EmptyView()
        }
    }

    private static let freshnessFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private static let accessibleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

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
