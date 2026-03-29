import SwiftUI

//
//  OpenClawTraderApp.swift
//  OpenClawTrader
//
//  功能：App入口文件，配置主题管理和根视图
//

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
