import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .tint(Color.beansAmber)
    }
}

struct MainView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("音乐库", systemImage: "music.note.list") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentSong != nil {
                MiniPlayerBar()
            }
        }
    }
}