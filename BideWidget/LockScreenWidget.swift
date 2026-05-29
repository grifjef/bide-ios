import SwiftUI
import WidgetKit

/// Lock Screen accessory widget (iOS 16+) showing Bide's lifetime
/// reclaim at a glance — circular and inline families. Glanceable
/// without unlocking: a quiet ambient nudge that the habit is working.
struct LockScreenWidget: Widget {
    let kind = "com.bidephoto.bide.widget.lockscreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BideWidgetProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Bide reclaimed")
        .description("Lifetime storage reclaimed, on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BideWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            // Inline renders next to the clock — a single tinted line.
            Label("\(entry.data.formattedLifetimeBytes) reclaimed", systemImage: "leaf.fill")
                .accessibilityLabel("Bide: \(entry.data.formattedLifetimeBytes) reclaimed lifetime")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("Bide", systemImage: "leaf.fill")
                    .font(.caption2.weight(.semibold))
                Text(entry.data.formattedLifetimeBytes)
                    .font(.headline.weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("reclaimed lifetime")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bide: \(entry.data.formattedLifetimeBytes) reclaimed lifetime")

        default:
            // Circular: a gauge-style compact reading. We show the value
            // with a leaf glyph above; AccessoryWidgetBackground gives the
            // standard translucent ring.
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                    Text(compactBytes)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(2)
            }
            .accessibilityLabel("Bide: \(entry.data.formattedLifetimeBytes) reclaimed lifetime")
        }
    }

    /// Tighter byte string for the circular family where space is scarce.
    /// `ByteCountFormatter` has no fraction-digit control, so we render
    /// with `.memory`/`.file` and strip a trailing ".0" if present —
    /// "4 GB" reads cleaner than "4.0 GB" in the tiny circular slot.
    private var compactBytes: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        let raw = formatter.string(fromByteCount: entry.data.lifetimeBytes)
        return raw.replacingOccurrences(of: ".0 ", with: " ")
    }
}
