import SwiftUI
import Photos

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryService.self) private var photoLibrary

    var body: some View {
        NavigationStack {
            List {
                Section {
                    privacyPromise
                } header: {
                    Text("Privacy")
                }

                Section {
                    Label {
                        Text("Photo access: \(authStatusText)")
                    } icon: {
                        Image(systemName: "photo.stack")
                            .foregroundStyle(BideTheme.primary)
                    }
                    Button("Manage in iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Permissions")
                }

                Section {
                    Label("Version 0.1.0", systemImage: "info.circle")
                    Link(destination: URL(string: "https://github.com/grifjef/bide-ios")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var privacyPromise: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            ForEach(privacyLines, id: \.self) { line in
                HStack(alignment: .top, spacing: BideTheme.s) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BideTheme.primary)
                        .imageScale(.small)
                        .padding(.top, 2)
                    Text(line)
                        .font(BideTheme.body())
                }
            }
        }
    }

    private var privacyLines: [String] {
        [
            "Bide runs entirely on this device.",
            "No account or sign-in.",
            "No photos uploaded by us.",
            "No third-party tracking or ads.",
            "Deletion goes to Recently Deleted (30-day recovery)."
        ]
    }

    private var authStatusText: String {
        switch photoLibrary.authStatus {
        case .authorized: return "Full"
        case .limited: return "Limited"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not determined"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
        .environment(PhotoLibraryService())
}
