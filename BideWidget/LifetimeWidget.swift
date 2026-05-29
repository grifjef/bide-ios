import SwiftUI
import WidgetKit

/// Home Screen widget showing Bide's lifetime reclaim total. Small and
/// medium families. The number is the user's own — never transmitted —
/// and seeing it on the home screen is a gentle, ambient reminder that
/// the calm-cleanup habit is paying off.
struct LifetimeWidget: Widget {
    let kind = "com.bidephoto.bide.widget.lifetime"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BideWidgetProvider()) { entry in
            LifetimeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("Colors/BidePrimary")
                }
        }
        .configurationDisplayName("Reclaimed with Bide")
        .description("Your lifetime storage reclaimed, and when you last tidied up.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LifetimeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BideWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                Text("Bide")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(entry.data.formattedLifetimeBytes)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("reclaimed")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bide. \(entry.data.formattedLifetimeBytes) reclaimed lifetime.")
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                    Text("Bide")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                Text(entry.data.formattedLifetimeBytes)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("reclaimed across \(entry.data.sessionCount) session\(entry.data.sessionCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Divider().overlay(.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 6) {
                statLine(value: "\(entry.data.itemCount)", label: "items cleared")
                statLine(value: lastTidyText, label: "last tidy")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumAccessibilityLabel)
    }

    private func statLine(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var lastTidyText: String {
        guard let date = entry.data.lastSessionAt else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: entry.date)
    }

    private var mediumAccessibilityLabel: String {
        var parts = ["Bide. \(entry.data.formattedLifetimeBytes) reclaimed across \(entry.data.sessionCount) sessions, \(entry.data.itemCount) items cleared."]
        if entry.data.lastSessionAt != nil {
            parts.append("Last tidy \(lastTidyText).")
        }
        return parts.joined(separator: " ")
    }
}
