import SwiftUI
import UIKit

enum RootTab: String, CaseIterable, Identifiable {
    case discover
    case search
    case library
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "发现"
        case .search: return "搜索"
        case .library: return "音乐库"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .discover: return "sparkles"
        case .search: return "magnifyingglass"
        case .library: return "music.note.list"
        case .profile: return "person.crop.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    @State private var selection: RootTab = .discover
    @State private var showPlayer = false

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
            // 免登录：默认进入主界面；自定义背景同步开启时全局生效
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)

            // 系统原生 TabView：iOS 26 上 UITabBar 自动使用原生液态玻璃，
            // 按压折射反馈、拖动效果、高光均由系统渲染（与应用商店等系统 App 一致）
            TabView(selection: $selection) {
                DiscoverView()
                    .background(Color.clear)
                    .tabItem { Label("发现", systemImage: "sparkles") }
                    .tag(RootTab.discover)
                SearchView()
                    .background(Color.clear)
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(RootTab.search)
                LibraryView()
                    .background(Color.clear)
                    .tabItem { Label("音乐库", systemImage: "music.note.list") }
                    .tag(RootTab.library)
                ProfileView()
                    .background(Color.clear)
                    .tabItem { Label("我的", systemImage: "person.crop.circle") }
                    .tag(RootTab.profile)
            }
            .tint(Color.beansAmber)
            .background(Color.clear)

            // 迷你播放器：悬浮在系统 TabBar 上方
            VStack(spacing: 0) {
                Spacer()
                if player.currentSong != nil {
                    MiniPlayerView(showPlayer: $showPlayer)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 62)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(themeMode.colorScheme)
        .onAppear { TabBarStyler.apply(alpha: theme.tabBarAlpha) }
        .onChange(of: theme.tabBarAlpha) { _, newAlpha in
            TabBarStyler.apply(alpha: newAlpha)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(player)
                .environmentObject(auth)
        }
        .animation(.spring(duration: 0.4), value: player.currentSong?.id)
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
    }
}


// MARK: - 系统 TabBar 液态玻璃透明度调节（动态应用到 UITabBar，深浅模式自适应）

enum TabBarStyler {
    static func apply(alpha: CGFloat) {
        let appearance = UITabBarAppearance()
        // 透明配置 + 按主题取底色，透明度由滑块控制（越小越透）
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor { traits in
            let base = traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.06, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
            return base.withAlphaComponent(min(max(alpha, 0.1), 1.0))
        }
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().tintColor = UIColor.beansAmber
        }
    }
}
