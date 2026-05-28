import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Banner shown on the dashboard when the user granted Limited Library Access
/// (i.e. picked a specific subset of photos rather than the whole library).
///
/// We treat limited mode as honest, not as a bug — but the user deserves to
/// know that scans will be partial, and we offer a one-tap shortcut to expand
/// the selection via the system picker.
struct LimitedLibraryBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack(spacing: BideTheme.s) {
                Image(systemName: "photo.stack.fill")
                    .foregroundStyle(BideTheme.accent)
                Text("Limited photo access")
                    .font(BideTheme.cardTitle())
            }

            Text("Bide can only see the photos you picked. Scans will be partial. You can pick more anytime — nothing is uploaded by us.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: BideTheme.s) {
                Button("Pick more photos") {
                    presentLimitedPicker()
                }
                .buttonStyle(.borderedProminent)
                .tint(BideTheme.accent)
                .controlSize(.small)

                Button("Manage in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Limited photo access. Scans will be partial. Tap to pick more photos or manage in Settings.")
    }

    /// Present the system limited-library picker so the user can expand the
    /// set of photos Bide can see. Requires a view controller to anchor on —
    /// we find the key window's root via UIScene API (iOS 17+).
    private func presentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene,
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }

        // Walk to the topmost presented controller so the picker overlays cleanly.
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }
}

#Preview {
    LimitedLibraryBanner()
        .padding()
        .background(BideTheme.background)
}
