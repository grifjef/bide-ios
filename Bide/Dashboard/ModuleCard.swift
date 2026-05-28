import SwiftUI

struct ModuleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var disabled: Bool = false
    var badge: String?

    var body: some View {
        HStack(alignment: .center, spacing: BideTheme.m) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(disabled ? BideTheme.textTertiary : BideTheme.primary)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: BideTheme.xs) {
                HStack {
                    Text(title)
                        .font(BideTheme.cardTitle())
                        .foregroundStyle(disabled ? BideTheme.textSecondary : BideTheme.textPrimary)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, BideTheme.s)
                            .padding(.vertical, 2)
                            .background(BideTheme.warning.opacity(0.18))
                            .foregroundStyle(BideTheme.warning)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if !disabled {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BideTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
        .opacity(disabled ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint(disabled ? "Disabled" : "Opens \(title)")
    }
}

#Preview {
    VStack(spacing: 12) {
        ModuleCard(
            icon: "video.circle.fill",
            title: "Large videos",
            subtitle: "Find the biggest files first."
        )
        ModuleCard(
            icon: "square.on.square.dashed",
            title: "Similar photos",
            subtitle: "Coming soon — careful clustering of near-duplicates.",
            disabled: true,
            badge: "Soon"
        )
    }
    .padding()
    .background(BideTheme.background)
}
