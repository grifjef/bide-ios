import SwiftUI

struct ReviewBasketView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ReviewBasket.self) private var basket
    @Environment(PhotoLibraryService.self) private var photoLibrary

    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var deletionResult: DeletionResult?
    @State private var summarySession: CompletionSummary?

    struct CompletionSummary: Identifiable {
        let id = UUID()
        let count: Int
        let bytes: Int64
        let completedAt: Date

        var formattedBytes: String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    enum DeletionResult: Equatable {
        case success(count: Int, bytes: Int64)
        case cancelled
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.m) {
                headerCard

                ForEach(ReviewBasket.Source.allCases, id: \.self) { source in
                    let items = basket.items(from: source)
                    if !items.isEmpty {
                        sectionView(source: source, items: items)
                    }
                }

                Spacer(minLength: BideTheme.xxl)
            }
            .padding(BideTheme.m)
        }
        .background(BideTheme.background)
        .navigationTitle("Review basket")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if !basket.isEmpty {
                bottomBar
            }
        }
        .alert("Move to Recently Deleted?", isPresented: $isConfirming) {
            Button("Cancel", role: .cancel) { }
            Button("Move \(basket.count) item\(basket.count == 1 ? "" : "s")", role: .destructive) {
                Task { await confirmDeletion() }
            }
        } message: {
            Text("These items will move to Photos' Recently Deleted album. You can recover them there for 30 days.")
        }
        .alert(item: $deletionResult) { result in
            switch result {
            case .success:
                // Success uses the fullscreen summary instead of an alert.
                return Alert(title: Text(""), dismissButton: .default(Text("Done")))
            case .cancelled:
                return Alert(
                    title: Text("Cancelled"),
                    message: Text("Nothing was deleted."),
                    dismissButton: .default(Text("OK"))
                )
            case .failed(let message):
                return Alert(
                    title: Text("Something went wrong"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .sheet(item: $summarySession) { session in
            SessionSummaryView(session: session) {
                summarySession = nil
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            Text("\(basket.count) item\(basket.count == 1 ? "" : "s") selected")
                .font(BideTheme.cardTitle())
            Text("Estimated reclaim: \(basket.formattedTotalSize)")
                .font(BideTheme.numeric())
                .foregroundStyle(BideTheme.primary)
            Divider()
            Label(
                "Nothing is deleted permanently. Everything moves to Recently Deleted for 30 days.",
                systemImage: "arrow.uturn.backward.circle"
            )
            .font(BideTheme.caption())
            .foregroundStyle(BideTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private func sectionView(source: ReviewBasket.Source, items: [ReviewBasket.Item]) -> some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack {
                Text(source.displayName)
                    .font(BideTheme.cardTitle())
                Spacer()
                Text("\(items.count)")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            VStack(spacing: BideTheme.xs) {
                ForEach(items) { item in
                    BasketItemRow(item: item) {
                        basket.remove(localIdentifier: item.id)
                    }
                }
            }
        }
        .padding(.top, BideTheme.s)
    }

    private var bottomBar: some View {
        VStack(spacing: BideTheme.s) {
            Button {
                isConfirming = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BideTheme.m)
                } else {
                    Text("Move to Recently Deleted")
                        .font(BideTheme.cardTitle())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BideTheme.m)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(BideTheme.accent)
            .disabled(isDeleting)

            Button("Cancel basket") {
                basket.clear()
                dismiss()
            }
            .font(BideTheme.caption())
            .foregroundStyle(BideTheme.textSecondary)
            .disabled(isDeleting)
        }
        .padding(.horizontal, BideTheme.m)
        .padding(.vertical, BideTheme.s)
        .background(.thinMaterial)
    }

    private func confirmDeletion() async {
        let toDelete = basket.items.map(\.id)
        let totalBytes = basket.totalBytes
        let count = basket.count

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await photoLibrary.delete(identifiers: toDelete)
            basket.clear()
            summarySession = CompletionSummary(
                count: count,
                bytes: totalBytes,
                completedAt: Date()
            )
        } catch {
            // PhotoKit throws if the user denies the system confirmation sheet.
            // That's a user-cancel, not a real error.
            let nsError = error as NSError
            if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3072 {
                deletionResult = .cancelled
            } else {
                deletionResult = .failed(error.localizedDescription)
            }
        }
    }
}

// Make DeletionResult Identifiable for the .alert(item:) modifier
extension ReviewBasketView.DeletionResult: Identifiable {
    var id: String {
        switch self {
        case .success: return "success"
        case .cancelled: return "cancelled"
        case .failed: return "failed"
        }
    }
}

private struct BasketItemRow: View {
    let item: ReviewBasket.Item
    let onRemove: () -> Void

    var body: some View {
        HStack {
            ThumbnailView(localIdentifier: item.id)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: item.estimatedBytes, countStyle: .file))
                    .font(BideTheme.numeric())
                if let date = item.displayDate {
                    Text(date)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(BideTheme.textTertiary)
            }
            .accessibilityLabel("Remove from basket")
        }
        .padding(BideTheme.s)
        .background(BideTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
    }
}
