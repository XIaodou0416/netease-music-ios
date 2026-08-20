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
            GlassBackdrop()

            if auth.isLoggedIn {
                tabContent
                    .id(selection)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
            }

            if auth.isLoggedIn {
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

// MARK: - 液态玻璃底栏（玻璃效果仅作背景装饰，不包裹按钮，保证可交互；长按触发液态涟漪 + 播放快捷菜单）

struct AppStoreTabBar: View {
    @EnvironmentObject private var theme: ThemeStore
    @Binding var selection: RootTab
    @EnvironmentObject private var player: PlayerManager

    @State private var menuTab: RootTab?
    @State private var rippleTab: RootTab?
    @State private var anchors: [RootTab: CGFloat] = [:]
    @State private var showQueue = false

    private let menuWidth: CGFloat = 176

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if let menuTab, player.currentSong != nil {
                    quickMenu(for: menuTab)
                        .frame(width: menuWidth)
                        .padding(.bottom, 82)
                        .offset(x: menuOffset(for: menuTab, width: geo.size.width))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
                barCapsule
                    .simultaneousGesture(dragToSelect(width: geo.size.width))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "beansTabBar")
        }
        .frame(height: 64)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .sheet(isPresented: $showQueue) { QueueView().environmentObject(player) }
    }

    private var barCapsule: some View {
        ZStack {
            SlidingIndicator(selection: $selection)
            HStack(spacing: 4) {
                ForEach(RootTab.allCases) { tab in
                    tabButton(tab)
                }
            }
        }
        .padding(5)
        .background {
            // iOS 26 原生液态玻璃：真玻璃材质 + 高光 + 描边
            GlassEffectContainer {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.clear, in: Capsule())
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        Button {
            tap(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == tab ? Color.beansAmber : Color.beansSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .scaleEffect(rippleTab == tab ? 1.12 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: rippleTab)
            .background {
                if rippleTab == tab {
                    LiquidRippleEffect()
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 14) {
            longPress(tab)
        }
        .background(anchorReader(tab))
    }

    private func anchorReader(_ tab: RootTab) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { anchors[tab] = geo.frame(in: .named("beansTabBar")).midX }
        }
    }

    private func menuOffset(for tab: RootTab, width: CGFloat) -> CGFloat {
        let anchor = anchors[tab] ?? width / 2
        let half = menuWidth / 2
        let clamped = min(max(anchor, half), max(width - half, half))
        return clamped - width / 2
    }

    private func quickMenu(for tab: RootTab) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color.beansSecondary)
            .padding(.bottom, 3)

            menuAction(icon: player.isPlaying ? "pause.fill" : "play.fill",
                       title: player.isPlaying ? "暂停" : "播放") {
                player.togglePlayPause()
                dismissMenu()
            }
            menuAction(icon: "backward.fill", title: "上一首") {
                player.previous()
                dismissMenu()
            }
            menuAction(icon: "forward.fill", title: "下一首") {
                player.next()
                dismissMenu()
            }
            menuAction(icon: "list.bullet", title: "播放队列") {
                dismissMenu()
                showQueue = true
            }
        }
        .padding(8)
        .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.08)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 10)
    }

    private func menuAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.beansLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if menuTab != nil { menuTab = nil }
        }
        if selection != tab {
            BeansHaptics.select()
            withAnimation(.spring(response: 0.3)) {
                selection = tab
            }
        }
    }

    private func longPress(_ tab: RootTab) {
        BeansHaptics.medium()
        rippleTab = tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if rippleTab == tab {
                withAnimation(.easeOut(duration: 0.25)) { rippleTab = nil }
            }
        }
        guard player.currentSong != nil else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            menuTab = tab
        }
    }

    private func dismissMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            menuTab = nil
        }
    }
}

// MARK: - 液态涟漪（长按扩散的玻璃波纹）

// MARK: - 液态玻璃选中指示器（独立视图，位于按钮层之下，半透明清透不遮挡图标）

struct SlidingIndicator: View {
    @Binding var selection: RootTab

    var body: some View {
        GeometryReader { geo in
            let count = CGFloat(max(RootTab.allCases.count, 1))
            let tabWidth = max((geo.size.width - 10 - 4 * (count - 1)) / count, 0)
            let index = CGFloat(RootTab.allCases.firstIndex(of: selection) ?? 0)
            GlassEffectContainer {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.thin, in: Capsule())
            }
            .overlay {
                Capsule().fill(Color.beansAmber.opacity(0.16))
            }
            .overlay {
                Capsule().strokeBorder(Color.beansAmber.opacity(0.32), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
            .frame(width: tabWidth, height: geo.size.height - 10)
            .offset(x: 5 + index * (tabWidth + 4))
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: selection)
            .allowsHitTesting(false)
        }
    }
}

struct LiquidRippleEffect: View {
    @State private var active = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .scaleEffect(active ? 1.28 : 0.35)
                .opacity(active ? 0 : 0.9)
            Capsule()
                .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                .scaleEffect(active ? 1.55 : 0.3)
                .opacity(active ? 0 : 0.85)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                active = true
            }
        }
    }
}
