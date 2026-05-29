import SwiftUI

/// Settings → About → "Acknowledgements". Bide ships with **zero
/// third-party dependencies** — no SPM packages, no vendored SDKs — so
/// this page is short and, unusually for the genre, completely honest:
/// everything is Apple's own frameworks plus Bide's own code under MIT.
///
/// Listing the frameworks explicitly is part of the trust story. A
/// "cleaner" app with no analytics SDK to hide has nothing to bury here.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                Text("Bide is built entirely on Apple's own frameworks. It bundles no third-party libraries, no analytics SDKs, and no advertising code. There is nothing here we'd want to hide — which is the point.")
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
            } header: {
                Text("No third-party code")
            }

            Section {
                ForEach(Self.frameworks, id: \.name) { framework in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(framework.name)
                            .font(BideTheme.cardTitle())
                        Text(framework.purpose)
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Apple frameworks Bide uses")
            }

            Section {
                Link(destination: URL(string: "https://github.com/grifjef/bide-ios/blob/main/LICENSE")!) {
                    Label("Bide source — MIT License", systemImage: "doc.text")
                }
            } header: {
                Text("Bide's own code")
            } footer: {
                Text("Bide is open source. You can read every line, including the parts that prove these privacy claims.")
                    .font(BideTheme.caption())
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Framework {
        let name: String
        let purpose: String
    }

    private static let frameworks: [Framework] = [
        Framework(name: "SwiftUI", purpose: "The entire user interface."),
        Framework(name: "PhotoKit", purpose: "Reading your photo library and moving items to Recently Deleted."),
        Framework(name: "Vision", purpose: "On-device image similarity, face detection, and screenshot OCR."),
        Framework(name: "SwiftData", purpose: "The local index that makes repeat scans fast."),
        Framework(name: "WidgetKit", purpose: "The Home Screen and Lock Screen widgets."),
        Framework(name: "App Intents", purpose: "Siri and Shortcuts support."),
        Framework(name: "Core Spotlight", purpose: "Making Bide's modules searchable from the home screen."),
        Framework(name: "BackgroundTasks", purpose: "Refreshing the dashboard overnight."),
        Framework(name: "MetricKit", purpose: "Apple's own performance and crash diagnostics — the only diagnostics Bide uses."),
        Framework(name: "StoreKit", purpose: "Not used. Bide has no in-app purchases.")
    ]
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
