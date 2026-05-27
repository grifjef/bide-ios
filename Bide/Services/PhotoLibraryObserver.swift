import Foundation
import Photos

/// Subscribes to the iOS photo library and invokes a callback when the library
/// mutates while we're using it (other apps editing photos, user editing in Photos,
/// new captures, iCloud syncing down deletions, etc).
///
/// Active scans should observe library changes and invalidate stale results —
/// otherwise we can suggest "delete this" for an asset that no longer exists.
///
/// Usage:
/// ```swift
/// let observer = PhotoLibraryObserver { change in
///     // Invalidate clusters whose assets were removed
/// }
/// // observer holds the registration until it deinits
/// ```
final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {

    private let onChange: @Sendable (PHChange) -> Void

    init(_ onChange: @escaping @Sendable (PHChange) -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ change: PHChange) {
        onChange(change)
    }
}
