import SwiftUI
import UIKit

/// Celebratory close-out screen shown after the user moves items to Recently
/// Deleted. Reinforces three things:
///   1. What was accomplished (count + bytes — concrete, not vague)
///   2. The 30-day recovery promise (explicit, with a "Open Recently Deleted"
///      deep link to Photos for users who want to double-check)
///   3. The session ends on a calm, positive note — not an alert that the user
///      dismisses and forgets
struct SessionSummaryView: View {
    let session: ReviewBasketView.CompletionSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: BideTheme.l) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76, weight: .light))
                .foregroundStyle(BideTheme.primary)

            VStack(spacing: BideTheme.s) {
                Text(session.formattedBytes)
                    .font(BideTheme.display())
                    .foregroundStyle(BideTheme.textPrimary)

                Text("\(session.count) item\(session.count == 1 ? "" : "s") moved to Recently Deleted")
                    .font(BideTheme.cardTitle())
                    .foregroundStyle(BideTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if let lifetime = session.lifetime, lifetime.sessionCount > 1 {
                    Text(lifetimeBlurb(lifetime))
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, BideTheme.s)
                }
            }

            VStack(alignment: .leading, spacing: BideTheme.m) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("30 days to change your mind")
                            .font(BideTheme.cardTitle())
                        Text("Anything you moved is sitting in Photos > Albums > Recently Deleted. Restore from there anytime before the 30-day window closes.")
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundStyle(BideTheme.accent)
                        .imageScale(.large)
                }

                Button {
                    openRecentlyDeleted()
                } label: {
                    Label("Open Recently Deleted in Photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .controlSize(.regular)
            }
            .padding(BideTheme.m)
            .background(BideTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(BideTheme.cardTitle())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BideTheme.m)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(BideTheme.accent)
        }
        .padding(BideTheme.l)
        .background(BideTheme.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.count) items moved to Recently Deleted. Freed \(session.formattedBytes). 30 days to restore from Photos if needed.")
    }

    /// Plain-English summary of lifetime reclaim. We avoid percentages and
    /// gamification — just the count of sessions and total bytes cleared,
    /// stated as fact.
    private func lifetimeBlurb(_ lifetime: ReclaimHistoryStore.LifetimeTotals) -> String {
        "You've cleared \(lifetime.formattedBytes) across \(lifetime.sessionCount) sessions with Bide."
    }

    /// Open the Recently Deleted album in Photos.app. The standard photos-redirect
    /// URL scheme launches Photos and lands on the user's library — they need to
    /// tap into the album themselves. (Apple does not currently expose a direct
    /// deep link to the Recently Deleted album.)
    private func openRecentlyDeleted() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SessionSummaryView(
        session: .init(
            count: 47,
            bytes: 1_240_000_000,
            completedAt: Date(),
            lifetime: .init(sessionCount: 8, itemCount: 312, bytes: 18_400_000_000, firstSessionAt: Date().addingTimeInterval(-60 * 60 * 24 * 90))
        ),
        onDone: {}
    )
}
