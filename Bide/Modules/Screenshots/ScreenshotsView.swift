import SwiftUI

/// Placeholder — full screenshots module lands in Phase 1.5.
/// Phase 1 ships Large Videos as the headline experience.
struct ScreenshotsView: View {
    var body: some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("Screenshots — coming next")
                .font(BideTheme.cardTitle())
            Text("Bide is shipping Large Videos first. Screenshots and Similar Photos land in the next updates.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BideTheme.background)
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.large)
    }
}
