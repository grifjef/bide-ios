import Foundation
import SwiftData

/// One row per successful deletion session. The user's lifetime reclaim total
/// is just the sum of these rows — no separate counter to drift out of sync.
@Model
final class ReclaimSession {
    /// Wall-clock time the user confirmed deletion.
    var completedAt: Date

    /// Number of items moved to Recently Deleted in this session.
    var itemCount: Int

    /// Sum of `estimatedBytes` for items in this session. This is the user's
    /// own number — never transmitted anywhere.
    var bytesReclaimed: Int64

    init(completedAt: Date, itemCount: Int, bytesReclaimed: Int64) {
        self.completedAt = completedAt
        self.itemCount = itemCount
        self.bytesReclaimed = bytesReclaimed
    }
}
