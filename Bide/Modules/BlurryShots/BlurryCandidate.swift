import Foundation

/// Value type for a single blurry-shot candidate. Carries enough metadata for
/// the protection check (favorite, hidden, recent) and the UI display, plus
/// the computed blur score.
struct BlurryCandidate: Identifiable, Hashable, Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let estimatedFileSize: Int64
    let isFavorite: Bool
    let isHidden: Bool
    let blurScore: Float        // lower = blurrier

    var id: String { localIdentifier }

    var resolution: Int { pixelWidth * pixelHeight }

    var formattedDate: String {
        guard let date = creationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedFileSize, countStyle: .file)
    }

    /// Verbal interpretation of the blur score, for UI ("Possibly blurry", "Likely blurry").
    /// We never say "definitely" — every candidate gets a human review.
    var confidenceLabel: String {
        if blurScore < 60 { return "Likely blurry" }
        if blurScore < 100 { return "Possibly blurry" }
        return "Borderline"
    }
}
