import SwiftUI

/// Centralized colors, typography, and spacing. Keeping the palette deliberately
/// muted and a touch sophisticated — Bide is not a candy-bright productivity app.
enum BideTheme {
    // MARK: - Colors

    /// Page backgrounds.
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)

    /// Card and module surfaces.
    static let surface = Color(.tertiarySystemBackground)

    /// Primary brand: muted forest green. Backed by `Colors/BidePrimary` in
    /// the asset catalog so light and dark mode each get a tuned value
    /// (dark mode lifts to maintain WCAG-AA contrast on dark backgrounds).
    static let primary = Color("Colors/BidePrimary", bundle: .main)

    /// Accent — slate blue. Used for active controls. Asset-catalog backed
    /// per `Colors/BideAccent`.
    static let accent = Color("Colors/BideAccent", bundle: .main)

    /// Soft warning amber. Used for "this will affect favorites" warnings.
    /// Asset-catalog backed per `Colors/BideWarning`.
    static let warning = Color("Colors/BideWarning", bundle: .main)

    /// For destructive actions only — used sparingly; we lean on iOS system red.
    static let destructive = Color(.systemRed)

    /// Text colors.
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    // MARK: - Spacing

    /// 8-point grid: x1 / x2 / x3 / x4 / x6
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Corner radii

    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let cornerLarge: CGFloat = 20

    // MARK: - Typography

    /// Display title — serif, gentle weight. Used sparingly (hero screens).
    static func display() -> Font {
        .system(.largeTitle, design: .serif, weight: .semibold)
    }

    /// Screen title.
    static func title() -> Font {
        .system(.title2, design: .default, weight: .semibold)
    }

    /// Card title.
    static func cardTitle() -> Font {
        .system(.headline, design: .default, weight: .medium)
    }

    /// Body copy.
    static func body() -> Font {
        .system(.body, design: .default)
    }

    /// Small label / metadata.
    static func caption() -> Font {
        .system(.footnote, design: .default, weight: .medium)
    }

    /// Numeric / tabular data.
    static func numeric() -> Font {
        .system(.body, design: .monospaced, weight: .medium)
    }
}

// MARK: - View modifiers

extension View {
    /// Apply Bide's standard card chrome.
    func bideCard(padding: CGFloat = BideTheme.m) -> some View {
        self
            .padding(padding)
            .background(BideTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))
    }
}
