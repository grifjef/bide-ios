import SwiftUI
import Photos

struct DashboardView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket

    @State private var showReviewBasket: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BideTheme.m) {
                    // Permission state banner
                    if !photoLibrary.hasReadAccess {
                        permissionBanner
                    }

                    // Module cards
                    VStack(spacing: BideTheme.m) {
                        NavigationLink {
                            LargeVideosView()
                        } label: {
                            ModuleCard(
                                icon: "video.circle.fill",
                                title: "Large videos",
                                subtitle: "Find the biggest files first.",
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
                                subtitle: "Group and review old screenshots.",
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

                        ModuleCard(
                            icon: "scribble.variable",
                            title: "Blurry shots",
                            subtitle: "Coming soon — never auto-suggested.",
                            disabled: true,
                            badge: "Soon"
                        )
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
        }
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
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .environment(PhotoLibraryService())
        .environment(ReviewBasket())
}
