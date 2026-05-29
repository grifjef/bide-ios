import SwiftUI

/// Content-shaped placeholder row used during scans (Similar Photos,
/// Blurry Shots) instead of a bare `ProgressView`. Hints at the shape
/// of the eventual result so users know what they're waiting for and
/// don't ask "is it stuck?"
///
/// The shimmer is gated against `accessibilityReduceMotion` — when the
/// user has Reduce Motion on, the row renders as a static muted bar.
struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.4

    var body: some View {
        HStack(spacing: BideTheme.m) {
            placeholder(width: 88, height: 88, cornerRadius: BideTheme.cornerSmall)
            VStack(alignment: .leading, spacing: BideTheme.xs) {
                placeholder(width: 140, height: 14, cornerRadius: 4)
                placeholder(width: 90, height: 10, cornerRadius: 3)
                placeholder(width: 70, height: 10, cornerRadius: 3)
            }
            Spacer(minLength: 0)
        }
        .padding(BideTheme.s)
        .background(BideTheme.surface, in: RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))
        .accessibilityHidden(true) // VoiceOver hears the parent loading state instead
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
    }

    @ViewBuilder
    private func placeholder(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(BideTheme.secondaryBackground)
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.plusLighter)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Vertical stack of `count` skeleton rows for "we're scanning, results
/// coming" states. Used by SimilarPhotosView + BlurryShotsView in place
/// of bare ProgressViews.
struct SkeletonRowStack: View {
    var count: Int = 4

    var body: some View {
        VStack(spacing: BideTheme.s) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
            }
        }
    }
}

#Preview {
    VStack {
        SkeletonRowStack(count: 5)
            .padding()
    }
    .background(BideTheme.background)
}
