import Foundation

/// Bucket a screenshot falls into based on how much text Vision found.
/// We never look at *what* the text says — only how much of it there is.
/// That's the entire privacy story for this feature: character counts in,
/// category out, original text is discarded.
enum ScreenshotCategory: Int, CaseIterable, Sendable, Identifiable {
    /// Screenshots with very little text — typically photos shared from
    /// another app, screen captures of art / games / maps / videos.
    case visual = 0

    /// Screenshots with moderate text — typically app UI captures where
    /// the labels and buttons add up to a sentence or two of OCR.
    case mixed = 1

    /// Screenshots with heavy text — chats, receipts, documents, articles,
    /// confirmation pages. The most common cleanup category for most users.
    case textHeavy = 2

    /// Used in storage for "haven't analyzed yet"; never exposed in UI filters.
    case unanalyzed = -1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .visual:     return "Visual"
        case .mixed:      return "App UI"
        case .textHeavy:  return "Text-heavy"
        case .unanalyzed: return "Not yet sorted"
        }
    }

    var iconName: String {
        switch self {
        case .visual:     return "photo.fill"
        case .mixed:      return "rectangle.on.rectangle.angled.fill"
        case .textHeavy:  return "text.alignleft"
        case .unanalyzed: return "questionmark.circle"
        }
    }

    /// Plain-English description shown in the filter sheet so users
    /// understand what bucket they're choosing.
    var explanation: String {
        switch self {
        case .visual:
            return "Screenshots with very little text — photos, games, art, maps."
        case .mixed:
            return "App screenshots with some text — labels, buttons, navigation."
        case .textHeavy:
            return "Chats, receipts, documents, articles — heavy on text."
        case .unanalyzed:
            return "Bide hasn't analyzed this screenshot yet."
        }
    }
}

/// Pure classification of "this screenshot has N characters of text" into
/// a `ScreenshotCategory`. Thresholds are deliberately wide and rounded —
/// the OCR is fast-mode (lossy) so there's noise in the character counts
/// and we shouldn't reach for surgical boundaries.
enum OCRClassifier {
    /// Threshold below which a screenshot is "visual" (few characters of OCR).
    static let visualMaxChars: Int = 60

    /// Threshold below which a screenshot is "mixed" (typical UI screenshot).
    /// Above this is "text-heavy" (chat, receipt, document).
    static let mixedMaxChars: Int = 300

    static func classify(textCharacterCount: Int) -> ScreenshotCategory {
        if textCharacterCount < visualMaxChars { return .visual }
        if textCharacterCount < mixedMaxChars { return .mixed }
        return .textHeavy
    }
}
