import SwiftUI
import WidgetKit

/// Entry point for the BideWidget extension. Bundles the Home Screen
/// lifetime widget and the Lock Screen accessory widget so both appear
/// in the widget gallery from one extension target.
@main
struct BideWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifetimeWidget()
        LockScreenWidget()
    }
}
