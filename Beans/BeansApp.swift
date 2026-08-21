import SwiftUI

@main
struct BeansApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var emailAuth = EmailAuthStore()
    @StateObject private var player = PlayerManager()
    @StateObject private var theme = ThemeStore.shared

    init() {
        // 启动时重新注册用户上传的全局字体（覆盖安装后依然生效）
        FontManager.reinstallIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(emailAuth)
                .environmentObject(player)
                .environmentObject(theme)
        }
    }
}
