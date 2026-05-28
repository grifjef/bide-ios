import SwiftUI

/// In-app explainer accessible from Settings → "How Bide works". Trust-
/// building artifact that mirrors the marketing landing page voice but
/// lives locally — the user has it without an internet round-trip, and
/// reviewers can read it without leaving the app.
///
/// Structure mirrors the dashboard sections so the mental model is the
/// same surface twice. Copy is brand-on: calm, deliberate, no urgency.
struct HowBideWorksView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.l) {
                introBlock
                principlesBlock
                modulesBlock
                protectionsBlock
                recoveryBlock
                privacyBlock
            }
            .padding(BideTheme.m)
        }
        .background(BideTheme.background)
        .navigationTitle("How Bide works")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("The whole idea")
                .font(BideTheme.title())
            Text("Bide is a calm, on-device way to review your photo library and clear what you don't want. Nothing leaves your iPhone. Nothing gets deleted without you saying so. Twice.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Text("The name *bide* means \"to dwell, to wait patiently.\" That's the whole product philosophy in one syllable.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var principlesBlock: some View {
        sectionCard(title: "How decisions work") {
            VStack(alignment: .leading, spacing: BideTheme.s) {
                principleRow(
                    icon: "hand.raised",
                    title: "Bide suggests. You decide.",
                    body: "Modules surface candidates and explain why. Nothing is pre-checked or auto-deleted. You add what you want to the Review Basket, look it over, then confirm."
                )
                principleRow(
                    icon: "tray",
                    title: "Two confirmations before anything moves.",
                    body: "When you tap \"Move to Recently Deleted\", Bide shows its own confirm, then iOS shows the system sheet on top of that. You can back out at either step."
                )
                principleRow(
                    icon: "arrow.uturn.backward",
                    title: "Every removal is reversible.",
                    body: "Items go to Photos > Albums > Recently Deleted, where iOS keeps them for 30 days. Bide never reaches into that album."
                )
            }
        }
    }

    private var modulesBlock: some View {
        sectionCard(title: "Eight ways to review") {
            VStack(alignment: .leading, spacing: BideTheme.m) {
                moduleRow(
                    icon: "doc.on.doc.fill",
                    title: "Exact duplicates",
                    body: "Byte-for-byte identical copies, found in seconds. Catches the imports and re-saves Photos' own duplicate-merger misses."
                )
                moduleRow(
                    icon: "record.circle.fill",
                    title: "Screen recordings",
                    body: "Usually the biggest disposable files in any library. Surfaced as a distinct module so the reclaim is obvious."
                )
                moduleRow(
                    icon: "video.circle.fill",
                    title: "Large videos",
                    body: "Sorted by size. Favorites and hidden videos are protected; recent captures show a soft \"recent\" badge so you pause before clearing."
                )
                moduleRow(
                    icon: "doc.on.doc",
                    title: "Screenshots",
                    body: "Grouped by month and year. Use Sort by type to bucket into chat / app / visual using on-device OCR (character count only, never the text)."
                )
                moduleRow(
                    icon: "livephoto",
                    title: "Live Photos",
                    body: "Each Live Photo carries a short video sidecar — about 40% of its size. Convert to a still photo to keep the moment and shed the sidecar."
                )
                moduleRow(
                    icon: "square.on.square.dashed",
                    title: "Similar photos",
                    body: "Time-bucketed clusters with a suggested keeper. Bide tells you why a photo was suggested (favorited, edited, higher resolution, …) so you can override knowingly."
                )
                moduleRow(
                    icon: "scribble.variable",
                    title: "Blurry shots",
                    body: "The most conservative module. Photos with faces are excluded; favorites and the last 30 days are hidden. What remains is genuine candidates."
                )
                moduleRow(
                    icon: "calendar.badge.clock",
                    title: "On this day",
                    body: "Photos taken on today's calendar day in past years. A calm, five-minute reason to open Bide every day — not just when storage gets tight."
                )
            }
        }
    }

    private var protectionsBlock: some View {
        sectionCard(title: "What's always protected") {
            VStack(alignment: .leading, spacing: BideTheme.s) {
                protectionRow(
                    label: "Favorites",
                    body: "Hard protection in every module. The toggle is disabled. You'd have to unfavorite the photo in Photos.app to be able to remove it."
                )
                protectionRow(
                    label: "Hidden photos",
                    body: "Hard protection. Hidden items can't be added to the Review Basket from any module."
                )
                protectionRow(
                    label: "Recent (<30 days)",
                    body: "Hard protection in Screenshots and Blurry Shots. Soft \"Recent capture\" badge in Large Videos, Screen Recordings, and Live Photos so you see the signal but still have agency."
                )
                protectionRow(
                    label: "Faces",
                    body: "Vision face detection runs locally on Blurry Shots candidates. Anything with a detected face is excluded."
                )
                protectionRow(
                    label: "Albums",
                    body: "Photos that are in a user album you created are excluded from auto-suggestion clustering and never selected as a non-keeper."
                )
            }
        }
    }

    private var recoveryBlock: some View {
        sectionCard(title: "If you change your mind") {
            VStack(alignment: .leading, spacing: BideTheme.s) {
                Text("Everything you remove with Bide lands in **Photos > Albums > Recently Deleted**. iOS keeps it there for 30 days, then deletes permanently.")
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
                Text("Bide never reaches into that album. It never has a \"Delete forever\" affordance. If you decide a removal was a mistake, the recovery path is the same path iOS provides for every deletion: open Photos, tap Recently Deleted, tap Recover.")
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
            }
        }
    }

    private var privacyBlock: some View {
        sectionCard(title: "Privacy in one paragraph") {
            VStack(alignment: .leading, spacing: BideTheme.s) {
                Text("Bide does not transmit your photos, photo metadata, OCR text, feature prints, or any usage data anywhere. There is no Bide backend. There are no third-party SDKs that touch your data. Apple's MetricKit framework is the only diagnostics involved, and it stays on your device — you can read every report in Settings > Diagnostics.")
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
                Text("All of this is verifiable in the public source on GitHub.")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textTertiary)
            }
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BideTheme.m) {
            Text(title)
                .font(BideTheme.title())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private func principleRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BideTheme.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(BideTheme.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BideTheme.cardTitle())
                Text(body)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func moduleRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BideTheme.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(BideTheme.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BideTheme.cardTitle())
                Text(body)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func protectionRow(label: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BideTheme.m) {
            Image(systemName: "checkmark.shield.fill")
                .font(.callout)
                .foregroundStyle(BideTheme.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(BideTheme.cardTitle())
                Text(body)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HowBideWorksView()
    }
}
