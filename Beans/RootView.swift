import SwiftUI

// ============================================================================
// 全新根视图：系统 TabView（iOS 26 原生液态玻璃标签栏，替代旧自定义玻璃底栏）
// + 全局迷你播放器（悬浮于标签栏上方）
// ============================================================================

struct RootView: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("音乐库", systemImage: "music.note.list")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(1)
        }
        .tint(Color.beansAmber)
        .overlay(alignment: .bottom) {
            if player.currentSong != nil {
                MiniPlayerView()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 56)   // 让出系统标签栏高度
            }
        }
        // 音乐库页点击登录卡 → 切到「我的」并弹出登录
        .onReceive(NotificationCenter.default.publisher(for: .init("beans.openLogin"))) { _ in
            selectedTab = 1
        }
    }
}