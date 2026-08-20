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
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    @State private var selection: RootTab = .discover
    @State private var showPlayer = false

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
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

// MARK: - 液态玻璃底栏（玻璃效果仅作背景装饰，不包裹按钮，保证可交互）

struct AppStoreTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    if selection != tab {
                        BeansHaptics.select()
                        withAnimation(.spring(duration: 0.3)) {
                            selection = tab
                        }
                    }
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
                    .background {
                        if selection == tab {
                            Capsule().fill(Color.beansAmber.opacity(0.18))
                        }
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                }
        }
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}