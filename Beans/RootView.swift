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

// MARK: - App Store 风格液态底栏

struct AppStoreTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    if selection != tab {
                        BeansHaptics.select()
                        withAnimation(.spring(duration: 0.35)) {
                            selection = tab
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.beansAmber : Color.beansSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Color.beansAmber.opacity(0.16))
                        }
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
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
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }
}