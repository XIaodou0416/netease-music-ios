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
                    GlassTabBar(selection: $selection)
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

// MARK: - 液态玻璃标签栏

struct GlassTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selection = tab
                    }
                } label: {
                    tabLabel(tab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    @ViewBuilder
    private func tabLabel(_ tab: RootTab) -> some View {
        let selected = selection == tab
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: 17, weight: .medium))
            Text(tab.title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(selected ? Color.beansAmber : Color.beansSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .modifier(SelectionGlassModifier(selected: selected))
    }
}

private struct SelectionGlassModifier: ViewModifier {
    let selected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if selected {
            content
                .glassEffect(.regular, in: .capsule)
                .clipShape(Capsule())
        } else {
            content
        }
    }
}