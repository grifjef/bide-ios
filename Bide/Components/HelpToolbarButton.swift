import SwiftUI

/// Shared trailing-toolbar "?" button that presents `HowBideWorksView`
/// as a sheet. Applied via the `.helpButton()` View modifier so every
/// module screen surfaces the same affordance in the same place — users
/// learn the gesture once and find it everywhere.
struct HelpToolbarButton: ToolbarContent {
    @Binding var showHelp: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .accessibilityLabel("How Bide works")
            .accessibilityHint("Double-tap to read about the modules, protections, and recovery")
        }
    }
}

extension View {
    /// Add a "?" trailing-toolbar button + How Bide Works sheet to any
    /// view that has its own NavigationStack-driven toolbar. The caller
    /// owns the `@State var showHelp` so independent screens don't share
    /// presentation state.
    func helpButton(isPresented: Binding<Bool>) -> some View {
        toolbar {
            HelpToolbarButton(showHelp: isPresented)
        }
        .sheet(isPresented: isPresented) {
            NavigationStack {
                HowBideWorksView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isPresented.wrappedValue = false }
                        }
                    }
            }
        }
    }
}
