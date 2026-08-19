import SwiftUI

enum BeansTab: Hashable {
    case library
    case profile
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @State private var selectedTab: BeansTab = .library

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView(tab: $selectedTab)
                .tabItem { Label("音乐库", systemImage: "music.note.list") }
                .tag(BeansTab.library)
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(BeansTab.profile)
        }
        .tint(Color.beansAmber)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentSong != nil {
                MiniPlayerBar()
            }
        }
    }
}