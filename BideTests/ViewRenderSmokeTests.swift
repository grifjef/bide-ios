@testable import Bide
import SwiftUI
import XCTest

/// Render smoke tests for the dependency-light top views. Uses SwiftUI's
/// `ImageRenderer` to render each to a `UIImage` and asserts a non-empty
/// result — catching the common SwiftUI regressions (crash-on-render,
/// missing environment, a force-unwrap in `body`, a malformed layout that
/// produces a zero-size image) WITHOUT brittle pixel comparison.
///
/// Why not pixel snapshots: they're fragile across Xcode / OS versions
/// and would require a third-party snapshot library — against Bide's
/// zero-dependency stance. The environment-heavy views (Dashboard,
/// Settings, modules) are exercised by the XCUITest suite, which renders
/// them for real; this file covers the value-input views that suite
/// doesn't deep-link into.
@MainActor
final class ViewRenderSmokeTests: XCTestCase {
    private func assertRenders<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 844))
        renderer.scale = 2
        let image = renderer.uiImage
        XCTAssertNotNil(image, "view failed to render to an image", file: file, line: line)
        if let image {
            XCTAssertGreaterThan(image.size.width, 0, "rendered image has zero width", file: file, line: line)
            XCTAssertGreaterThan(image.size.height, 0, "rendered image has zero height", file: file, line: line)
        }
    }

    func test_howBideWorksRenders() {
        assertRenders(NavigationStack { HowBideWorksView() })
    }

    func test_acknowledgementsRenders() {
        assertRenders(NavigationStack { AcknowledgementsView() })
    }

    func test_whatsNewRenders() {
        assertRenders(WhatsNewView(version: "1.2.0", onDismiss: {}))
    }

    func test_sessionSummaryRenders() {
        let summary = ReviewBasketView.CompletionSummary(
            count: 12,
            bytes: 1_800_000_000,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lifetime: .init(
                sessionCount: 6,
                itemCount: 412,
                bytes: 4_600_000_000,
                firstSessionAt: Date(timeIntervalSince1970: 1_650_000_000)
            )
        )
        assertRenders(SessionSummaryView(session: summary, onDone: {}))
    }

    func test_sessionSummaryFirstSessionRenders() {
        // First-ever session: no lifetime block.
        let summary = ReviewBasketView.CompletionSummary(
            count: 1,
            bytes: 5_000_000,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lifetime: nil
        )
        assertRenders(SessionSummaryView(session: summary, onDone: {}))
    }

    func test_skeletonRowStackRenders() {
        assertRenders(SkeletonRowStack(count: 5).padding())
    }

    func test_recentCaptureBadgeRenders() {
        assertRenders(RecentCaptureBadge().padding())
    }
}
