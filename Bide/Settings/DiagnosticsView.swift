import SwiftUI

/// Surfaces the on-device MetricKit payloads iOS has delivered to Bide.
/// Nothing here is transmitted — it's the user's own data, shown to make
/// the "no third-party telemetry" promise concrete.
struct DiagnosticsView: View {
    @Environment(MetricsService.self) private var metrics
    @State private var selected: MetricsService.StoredPayload?

    var body: some View {
        List {
            Section {
                aboutBlock
            } header: {
                Text("About")
            }

            if metrics.diagnostics.isEmpty {
                Section {
                    emptyRow
                } header: {
                    Text("Reports")
                }
            } else {
                Section {
                    ForEach(metrics.diagnostics) { payload in
                        Button {
                            selected = payload
                        } label: {
                            row(payload)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(metrics.diagnostics.count) report\(metrics.diagnostics.count == 1 ? "" : "s")")
                } footer: {
                    Text("Reports older than \(MetricsService.retentionDays) days are pruned automatically.")
                        .font(BideTheme.caption())
                }

                Section {
                    Button(role: .destructive) {
                        metrics.deleteAll()
                    } label: {
                        Label("Delete all reports", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { payload in
            DiagnosticDetailView(payload: payload)
        }
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("Bide receives performance and crash diagnostics from iOS via MetricKit. iOS delivers these reports once per day; they describe Bide's own CPU, memory, disk, and crash behavior — never your photos or any other personal content.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Everything below stays on this device. Bide does not transmit this data anywhere.")
                .font(BideTheme.caption().weight(.semibold))
                .foregroundStyle(BideTheme.primary)
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack(spacing: BideTheme.s) {
                Image(systemName: "tray")
                    .foregroundStyle(BideTheme.textTertiary)
                Text("No reports yet")
                    .font(BideTheme.cardTitle())
            }
            Text("iOS sends MetricKit reports once per day on app launch. If Bide hasn't been open for a full 24-hour cycle, there's nothing to show yet.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .padding(.vertical, BideTheme.xs)
    }

    private func row(_ payload: MetricsService.StoredPayload) -> some View {
        HStack(spacing: BideTheme.s) {
            Image(systemName: payload.kind.iconName)
                .foregroundStyle(payload.kind == .diagnostic ? BideTheme.warning : BideTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.kind.displayName)
                    .font(BideTheme.cardTitle())
                Text(payload.formattedDate)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BideTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(payload.kind.displayName), captured \(payload.formattedDate)")
        .accessibilityHint("Double-tap to read the full report")
    }
}

/// Modal detail view for a single payload — formatted JSON with a Share button.
struct DiagnosticDetailView: View {
    let payload: MetricsService.StoredPayload
    @Environment(MetricsService.self) private var metrics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BideTheme.s) {
                    Text(payload.formattedDate)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)

                    Text(metrics.readJSON(payload))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(BideTheme.m)
            }
            .navigationTitle(payload.kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: metrics.readJSON(payload), preview: SharePreview(payload.kind.displayName))
                        .accessibilityLabel("Share this report")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
