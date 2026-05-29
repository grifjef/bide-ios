import Photos
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(\.modelContext) private var modelContext

    @State private var lifetime: ReclaimHistoryStore.LifetimeTotals = .zero
    @State private var recentSessions: [ReclaimSession] = []
    @State private var showTipJar: Bool = false

    /// Number of sessions to surface in the "Recent sessions" block. Old
    /// sessions still feed lifetime totals — they're just folded into the
    /// summary line so the list stays a glanceable history, not an archive.
    private static let recentSessionLimit = 10

    /// Public link Bide points at when the user shares. Falls back to the
    /// repo for now; switches to bidephoto.com once the App Store v1.0
    /// goes live and the marketing domain is in DNS.
    private static let shareURL = URL(string: "https://github.com/grifjef/bide-ios")!

    /// Composed "1.1.0 (2)" string for the About row. Reads from the bundle
    /// at runtime so it can never go stale against project.yml — the previous
    /// hardcoded "0.1.0" was wrong by the time v1.1 was being prepared.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let marketing = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info?["CFBundleVersion"] as? String) ?? "?"
        return "\(marketing) (\(build))"
    }

    /// Personalized share copy. Includes the user's lifetime number when
    /// they've actually done something with the app — turns a generic plug
    /// into a small flex without exposing anything beyond a byte count.
    private var shareMessage: String {
        if lifetime.bytes > 0 {
            return "Bide just helped me free up \(lifetime.formattedBytes) on my iPhone. It's a calm, on-device photo declutter app — no ads, no account, no tracking."
        }
        return "Bide: a calm, on-device photo declutter app for iPhone. No ads, no account, no tracking. Worth a look."
    }

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

                if !recentSessions.isEmpty {
                    Section {
                        ForEach(recentSessions) { session in
                            recentSessionRow(session)
                        }
                    } header: {
                        Text("Recent sessions")
                    } footer: {
                        if lifetime.sessionCount > recentSessions.count {
                            let earlier = lifetime.sessionCount - recentSessions.count
                            Text("Showing the \(recentSessions.count) most recent. \(earlier) earlier session\(earlier == 1 ? "" : "s") feed into the lifetime total above.")
                                .font(BideTheme.caption())
                        } else {
                            Text("Each row is one confirmed cleanup. Bide doesn't track or transmit any of it.")
                                .font(BideTheme.caption())
                        }
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
                        HowBideWorksView()
                    } label: {
                        Label("How Bide works", systemImage: "book")
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text("A short guide to the modules, what's protected, and how recovery works. Useful before granting access, useful any time after.")
                        .font(BideTheme.caption())
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
                    ShareLink(
                        item: Self.shareURL,
                        subject: Text("Bide — Camera Roll Review"),
                        message: Text(shareMessage)
                    ) {
                        Label("Share Bide with a friend", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Spread the calm")
                } footer: {
                    Text("If Bide helped you, telling a friend is the entire growth model. No ads, no referral codes, no tracking — just the link.")
                        .font(BideTheme.caption())
                }

                Section {
                    Button {
                        showTipJar = true
                    } label: {
                        Label("Support Bide", systemImage: "heart")
                    }
                } header: {
                    Text("Optional support")
                } footer: {
                    Text("Three optional non-consumable tips. None of them unlock anything — Bide stays free for everyone, forever.")
                        .font(BideTheme.caption())
                }

                Section {
                    Label("Version \(Self.appVersion)", systemImage: "info.circle")
                    Link(destination: URL(string: "https://github.com/grifjef/bide-ios")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("About")
                }
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
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
                if let all = try? store.fetchAll() {
                    recentSessions = Array(all.prefix(Self.recentSessionLimit))
                }
            }
        }
    }

    private func recentSessionRow(_ session: ReclaimSession) -> some View {
        let bytesFormatted = ByteCountFormatter.string(
            fromByteCount: session.bytesReclaimed,
            countStyle: .file
        )
        let itemsLabel = "\(session.itemCount) item\(session.itemCount == 1 ? "" : "s")"
        return HStack(alignment: .center, spacing: BideTheme.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.relativeDateFormatter.localizedString(for: session.completedAt, relativeTo: Date()).capitalized)
                    .font(BideTheme.body())
                Text(Self.absoluteDateFormatter.string(from: session.completedAt))
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(bytesFormatted)
                    .font(BideTheme.numeric())
                    .foregroundStyle(BideTheme.primary)
                Text(itemsLabel)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(itemsLabel), \(bytesFormatted), on \(Self.accessibleDateFormatter.string(from: session.completedAt)).")
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let absoluteDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let accessibleDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

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
