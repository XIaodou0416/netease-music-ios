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
            // 主题切换时用 .id 强制重建整棵视图树：
            // 修复深浅色/跟随系统切换后部分界面（尤其液态玻璃、毛玻璃材质）
            // 不跟随刷新、需要重启 App 才生效的问题。
            .id(themeRaw)
            .preferredColorScheme(theme)
        }
    }
}