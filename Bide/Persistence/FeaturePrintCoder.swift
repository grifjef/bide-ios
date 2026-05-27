import Foundation
import Vision

/// Round-trip a `VNFeaturePrintObservation` between memory and SwiftData (`Data`).
/// Vision's observation classes conform to `NSSecureCoding`, so we use the keyed
/// archiver path — no custom serialization, no version-fragile field-by-field
/// mapping.
enum FeaturePrintCoder {

    /// Serialize a feature-print observation to `Data` suitable for SwiftData storage.
    /// Returns `nil` if the archiver fails (rare — VN classes implement NSSecureCoding
    /// correctly, so failures usually mean memory pressure or a broken object).
    static func encode(_ observation: VNFeaturePrintObservation) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(
                withRootObject: observation,
                requiringSecureCoding: true
            )
        } catch {
            return nil
        }
    }

    /// Deserialize a previously-encoded feature print. Returns `nil` if the data
    /// is corrupted, was archived under a different class, or unarchiving fails.
    static func decode(_ data: Data) -> VNFeaturePrintObservation? {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: data
            )
        } catch {
            return nil
        }
    }
}
