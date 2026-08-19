import SwiftUI

@main
struct BeansApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerManager()
    @AppStorage("beans.theme") private var themeRaw = BeansThemeMode.system.rawValue

    private var theme: ColorScheme? {
        switch BeansThemeMode(rawValue: themeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            GlassEffectContainer {
                RootView()
                    .environmentObject(auth)
                    .environmentObject(player)
            }
            .preferredColorScheme(theme)
        }
    }
}