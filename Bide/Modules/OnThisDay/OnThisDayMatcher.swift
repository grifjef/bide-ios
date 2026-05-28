import Foundation

/// Pure date-matching logic for the "On This Day" module. Given a target date
/// and a list of candidates, returns the candidates whose `creationDate` falls
/// on the same month + day in any previous year, grouped by year (newest year
/// first within the result).
///
/// Pulled into its own type so the date math is fully testable without any
/// PhotoKit dependency. The OnThisDayService just calls this.
enum OnThisDayMatcher {
    /// Items from past years that match the target month + day.
    struct YearGroup: Identifiable, Equatable {
        let id: Int           // year (e.g. 2024)
        let title: String     // "1 year ago" / "2 years ago"
        let items: [SimilarPhotoCandidate]
    }

    /// Returns groups for any candidate whose creationDate has the same month
    /// and day-of-month as `targetDate` but is from a strictly earlier year.
    /// Years are sorted newest-first.
    static func groupsForToday(
        candidates: [SimilarPhotoCandidate],
        targetDate: Date,
        calendar: Calendar = .current
    ) -> [YearGroup] {
        let targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
        guard let targetYear = targetComponents.year,
              let targetMonth = targetComponents.month,
              let targetDay = targetComponents.day
        else { return [] }

        var bucket: [Int: [SimilarPhotoCandidate]] = [:]
        for candidate in candidates {
            let comps = calendar.dateComponents([.year, .month, .day], from: candidate.creationDate)
            guard let year = comps.year,
                  let month = comps.month,
                  let day = comps.day
            else { continue }
            // Must be a previous year on the same calendar day.
            guard year < targetYear, month == targetMonth, day == targetDay else { continue }
            bucket[year, default: []].append(candidate)
        }

        return bucket
            .map { (year, items) -> YearGroup in
                let yearsAgo = targetYear - year
                let label = yearsAgo == 1 ? "1 year ago" : "\(yearsAgo) years ago"
                let sorted = items.sorted { $0.creationDate < $1.creationDate }
                return YearGroup(id: year, title: label, items: sorted)
            }
            .sorted { $0.id > $1.id }
    }

    /// Convenience: total count across all year groups.
    static func totalCount(_ groups: [YearGroup]) -> Int {
        groups.reduce(0) { $0 + $1.items.count }
    }
}
