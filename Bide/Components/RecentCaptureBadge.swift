import SwiftUI

/// Small inline label used on rows in modules where recency matters (Large
/// Videos, Screen Recordings, Live Photos). A *soft* signal — the user can
/// still select the item, but the badge tells them "this is from the last
/// 30 days, you might still want it" without blocking the action.
///
/// Modules where recency is already a hard protection (Screenshots, Blurry
/// Shots) don't use this badge — they hide or disable the row entirely.
struct RecentCaptureBadge: View {
    var body: some View {
        Label("Recent capture", systemImage: "clock.badge.checkmark")
            .font(.caption2.weight(.medium))
            .foregroundStyle(BideTheme.accent)
            .accessibilityLabel("Recent capture, taken in the last 30 days")
    }
}

#Preview {
    RecentCaptureBadge()
        .padding()
        .background(BideTheme.background)
}
