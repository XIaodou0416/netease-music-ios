import SwiftUI

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

            tabContent
                .id(selection)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            VStack(spacing: 0) {
                Spacer()
                if player.currentSong != nil {
                    MiniPlayerView(showPlayer: $showPlayer)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                AppStoreTabBar(selection: $selection)
            }
        }
        .preferredColorScheme(themeMode.colorScheme)
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

    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .discover: DiscoverView()
        case .search: SearchView()
        case .library: LibraryView()
        case .profile: ProfileView()
        }
    }
}

// MARK: - 悬浮液态玻璃底栏（iOS 26 glass 三层；原生长按触感 + 快捷菜单 / 滑动选中）

struct AppStoreTabBar: View {
    @EnvironmentObject private var theme: ThemeStore
    @Binding var selection: RootTab
    @EnvironmentObject private var player: PlayerManager

    @State private var showQueue = false
    @Namespace private var tabNS

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                barCapsule
                    .simultaneousGesture(dragToSelect(width: geo.size.width))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 64)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: selection)
        .sheet(isPresented: $showQueue) { QueueView().environmentObject(player) }
    }

    /// 悬浮液态玻璃底栏：iOS 26 原生 glass + 高光 + 描边三层，悬浮于内容之上
    private var barCapsule: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .background {
            GlassEffectContainer {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.clear, in: Capsule())
            }
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.22), .clear, .white.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        Button {
            tap(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .symbolVariant(selection == tab ? .fill : .none)
                    .font(.system(size: 17, weight: .medium))
                Text(tab.title)
                    .font(BeansFont.appFont(10, .medium))
            }
            .foregroundStyle(selection == tab ? Color.beansAmber : Color.beansSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if selection == tab {
                // 液态玻璃选中滑块：切换 tab 时平滑滑动（仿分段控件液态效果）
                GlassEffectContainer {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.clear, in: Capsule())
                }
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .matchedGeometryEffect(id: "beansTabPill", in: tabNS)
            }
        }
        .clipShape(Capsule())
        // 系统原生 context menu：长按弹出系统菜单（Haptic Touch 由系统提供，与分段控件等原生控件一致）
        .contextMenu {
            if player.currentSong != nil {
                Button {
                    BeansHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    Label(player.isPlaying ? "暂停" : "播放", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                }
                Button {
                    BeansHaptics.tap()
                    player.previous()
                } label: {
                    Label("上一首", systemImage: "backward.fill")
                }
                Button {
                    BeansHaptics.tap()
                    player.next()
                } label: {
                    Label("下一首", systemImage: "forward.fill")
                }
                Button {
                    BeansHaptics.tap()
                    showQueue = true
                } label: {
                    Label("播放队列", systemImage: "list.bullet")
                }
            }
        }
    }

    /// 触碰滑动选中：手指在底栏上横向滑动即可切换 tab（与点击 / 长按共存）
    private func dragToSelect(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let tabs = RootTab.allCases
                let count = max(tabs.count, 1)
                let index = min(max(Int(value.location.x / max(width / CGFloat(count), 1)), 0), count - 1)
                let tab = tabs[index]
                if selection != tab {
                    BeansHaptics.select()
                    withAnimation(.spring(response: 0.3)) {
                        selection = tab
                    }
                }
            }
    }

    private func tap(_ tab: RootTab) {
        if selection != tab {
            BeansHaptics.select()
            withAnimation(.spring(response: 0.3)) {
                selection = tab
            }
        }
    }

}
