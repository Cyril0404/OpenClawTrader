import SwiftUI

// ============================================
// MARK: - App Entry Point
// ============================================

@main
struct OpenClawTraderApp: App {
    @State private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .withAdaptiveColors()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
