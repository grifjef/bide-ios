import StoreKit
import SwiftUI

/// Settings → "Support Bide" sheet. Three optional non-consumable tip
/// tiers. Buying any of them changes nothing in the app — there is no
/// feature gate, no "Pro," no subscription. It's a thank-you, that's it.
///
/// The constraint is product-level: free download with optional one-time
/// IAP unlock. We chose "no unlock" — the IAPs are pure support.
struct TipJarView: View {
    @State private var store = TipJarStore()
    @State private var pendingPurchase: Product?
    @State private var latestOutcome: PurchaseOutcome?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BideTheme.l) {
                    intro
                    productList
                    outcomeBlock
                    restore
                    closingNote
                }
                .padding(BideTheme.m)
            }
            .background(BideTheme.background)
            .navigationTitle("Support Bide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("Free for everyone, forever")
                .font(BideTheme.title())
            Text("Bide doesn't lock features behind a tip. Nothing in this list unlocks anything. If the app helped you, this is just a way to say thanks — no subscription, no upsell, no email list.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var productList: some View {
        switch store.loadState {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, BideTheme.l)
        case .failed:
            VStack(alignment: .leading, spacing: BideTheme.s) {
                Text("Couldn't load the tip jar")
                    .font(BideTheme.cardTitle())
                Text(store.lastError ?? "Please check your connection and try again.")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                Button("Try again") {
                    Task { await store.loadProducts() }
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
            }
            .bideCard()
        case .loaded:
            VStack(spacing: BideTheme.s) {
                ForEach(store.products, id: \.id) { product in
                    tipRow(product)
                }
            }
        }
    }

    private func tipRow(_ product: Product) -> some View {
        let id = TipJarStore.TipID(rawValue: product.id)
        let alreadyTipped = id.map { store.isPurchased($0) } ?? false
        return HStack(alignment: .center, spacing: BideTheme.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(BideTheme.cardTitle())
                Text(product.description)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: BideTheme.s)
            if alreadyTipped {
                Label("Thanks!", systemImage: "heart.fill")
                    .labelStyle(.titleAndIcon)
                    .font(BideTheme.caption().weight(.semibold))
                    .foregroundStyle(BideTheme.primary)
            } else if pendingPurchase?.id == product.id {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Button {
                    Task { await buy(product) }
                } label: {
                    Text(product.displayPrice)
                        .font(BideTheme.numeric())
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(BideTheme.primary)
                .controlSize(.regular)
            }
        }
        .padding(.vertical, BideTheme.s)
        .padding(.horizontal, BideTheme.m)
        .background(BideTheme.surface, in: RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var outcomeBlock: some View {
        if let outcome = latestOutcome {
            switch outcome {
            case .succeeded:
                outcomePanel(
                    icon: "checkmark.circle.fill",
                    tint: BideTheme.primary,
                    title: "Thank you.",
                    body: "You just made Bide's next module possible. The app still works the same — no unlocks, no flags. Just gratitude."
                )
            case .userCancelled:
                EmptyView()
            case .pending:
                outcomePanel(
                    icon: "hourglass",
                    tint: BideTheme.accent,
                    title: "Pending approval",
                    body: "Apple is waiting on a payment method confirmation. We'll celebrate when it lands."
                )
            case .failed(let message):
                outcomePanel(
                    icon: "exclamationmark.triangle.fill",
                    tint: BideTheme.warning,
                    title: "Purchase didn't complete",
                    body: message
                )
            case .failedVerification:
                outcomePanel(
                    icon: "exclamationmark.shield",
                    tint: BideTheme.warning,
                    title: "Couldn't verify the receipt",
                    body: "Apple wasn't able to verify this purchase. Try again, or use Restore to recover any prior tips."
                )
            }
        }
    }

    private func outcomePanel(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: BideTheme.s) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BideTheme.cardTitle())
                Text(body)
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                latestOutcome = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(BideTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(BideTheme.s)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
    }

    private var restore: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore previous tips")
                .font(BideTheme.caption())
        }
        .buttonStyle(.bordered)
        .tint(BideTheme.accent)
        .frame(maxWidth: .infinity)
    }

    private var closingNote: some View {
        Text("If you'd rather not spend money, telling a friend works just as well. Settings → Spread the calm.")
            .font(BideTheme.caption())
            .foregroundStyle(BideTheme.textTertiary)
            .multilineTextAlignment(.leading)
    }

    // MARK: - Actions

    private func buy(_ product: Product) async {
        pendingPurchase = product
        let outcome = await store.purchase(product)
        latestOutcome = outcome
        if outcome.isSuccess {
            BideHaptics.success()
        }
        pendingPurchase = nil
    }
}

#Preview {
    TipJarView()
}
