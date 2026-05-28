import SwiftUI
import Photos

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.modelContext) private var modelContext

    @State private var lifetime: ReclaimHistoryStore.LifetimeTotals = .zero

    var body: some View {
        NavigationStack {
            List {
                if lifetime.sessionCount > 0 {
                    Section {
                        lifetimeRow
                    } header: {
                        Text("Lifetime with Bide")
                    } footer: {
                        Text("Your own number, never transmitted anywhere.")
                            .font(BideTheme.caption())
                    }
                }

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
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }
                } header: {
                    Text("Transparency")
                } footer: {
                    Text("See Apple's MetricKit reports about Bide's behavior on your device. Nothing is transmitted.")
                        .font(BideTheme.caption())
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
            .task {
                let store = ReclaimHistoryStore(modelContext: modelContext)
                if let totals = try? store.lifetimeTotals() {
                    lifetime = totals
                }
            }
        }
    }

    private var lifetimeRow: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text(lifetime.formattedBytes)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.primary)
            Text("Reclaimed across \(lifetime.sessionCount) session\(lifetime.sessionCount == 1 ? "" : "s")")
                .font(BideTheme.cardTitle())
            Text("\(lifetime.itemCount) item\(lifetime.itemCount == 1 ? "" : "s") moved to Recently Deleted in total.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .padding(.vertical, BideTheme.xs)
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
