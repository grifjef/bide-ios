import SwiftUI

/// One-shot sheet shown on the user's first launch after upgrading from a
/// prior version. Lives in the dashboard's overlay because that's the
/// first screen returning users see; gated by `WhatsNewPlanner` so fresh
/// installs and the in-onboarding flow never trip it.
///
/// Tone matches the rest of the brand: calm, specific, no marketing
/// language. The user is going to scroll the list, decide what they care
/// about, and move on. We don't try to keep them on this screen.
struct WhatsNewView: View {
    let version: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BideTheme.l) {
                    headline
                    highlights
                    footer
                }
                .padding(BideTheme.m)
            }
            .background(BideTheme.background)
            .navigationTitle("What's new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(BideTheme.cardTitle())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BideTheme.m)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(BideTheme.accent)
                .padding(BideTheme.m)
                .background(BideTheme.background)
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("Bide \(version)")
                .font(BideTheme.caption().weight(.semibold))
                .foregroundStyle(BideTheme.primary)
            Text("More modules, calmer review")
                .font(BideTheme.display())
            Text("Eight ways to clear your camera roll now, plus a few details that make day-to-day use feel like the rest of iOS.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: BideTheme.m) {
            highlightRow(
                icon: "livephoto",
                title: "Convert Live Photos to stills",
                body: "Keep the moment, drop the video sidecar. Reclaim about 40% of the file size without losing the photo."
            )
            highlightRow(
                icon: "doc.on.doc.fill",
                title: "Exact duplicates, found instantly",
                body: "A new module catches byte-for-byte copies that Apple's Duplicates album sometimes misses."
            )
            highlightRow(
                icon: "record.circle.fill",
                title: "Screen recordings get their own list",
                body: "Usually the biggest disposable files in your library — surfaced where they're easy to clear."
            )
            highlightRow(
                icon: "calendar.badge.clock",
                title: "On this day",
                body: "Photos taken on today's calendar day across past years. A calm five-minute reason to open Bide every day."
            )
            highlightRow(
                icon: "clock.arrow.circlepath",
                title: "Dashboard refreshes itself",
                body: "When the library changes — even in another app — your dashboard counts update without a pull-to-refresh."
            )
            highlightRow(
                icon: "list.bullet.rectangle",
                title: "Lifetime + recent sessions",
                body: "Settings now shows your reclaim history, ten most recent sessions, all of it on-device."
            )
            highlightRow(
                icon: "book",
                title: "How Bide works, in the app",
                body: "Settings → How Bide works explains every module, every protection, and the recovery promise."
            )
        }
    }

    private func highlightRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BideTheme.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(BideTheme.primary)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BideTheme.cardTitle())
                Text(body)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BideTheme.s)
        .background(BideTheme.surface, in: RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("Same promises")
                .font(BideTheme.cardTitle())
            Text("No accounts. No ads. No subscriptions. No third-party trackers. Nothing uploaded by us. Every removal still goes to Recently Deleted for 30 days.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .padding(.top, BideTheme.s)
    }
}

#Preview {
    WhatsNewView(version: "1.1.0", onDismiss: {})
}
