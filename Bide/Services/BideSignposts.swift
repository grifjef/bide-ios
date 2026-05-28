import Foundation
import os

/// Shared OSLog + signposter for Bide's scan hot paths. Lets Instruments
/// (Signposts template) and MetricKit attribute time to specific phases
/// of the pipeline — Dashboard pre-scan sections, Similar Photos scan
/// stages, Exact Duplicates grouping — without us building our own
/// performance harness.
///
/// All signposts are scoped to two categories so they don't drown out
/// regular logging:
///   - `scans`: pre-scan and on-demand scan operations
///   - `photokit`: PhotoKit fetch / resource calls
///
/// The subsystem matches the bundle ID so the signposts are easy to
/// filter in `log stream --subsystem com.bidephoto.bide`.
enum BideSignposts {

    static let subsystem = "com.bidephoto.bide"

    static let scansLog = OSLog(subsystem: subsystem, category: "scans")
    static let photoKitLog = OSLog(subsystem: subsystem, category: "photokit")

    static let scansSignposter = OSSignposter(subsystem: subsystem, category: "scans")
    static let photoKitSignposter = OSSignposter(subsystem: subsystem, category: "photokit")
}
