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
        ZStack(alignment: .bottom) {
            Color.beansBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .library:
                    LibraryView(tab: $selectedTab)
                        .transition(.opacity)
                case .profile:
                    ProfileView()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                if player.currentSong != nil {
                    MiniPlayerBar()
                }
                BeansTabBar(selected: $selectedTab)
            }
            .padding(.bottom, 6)
        }
        .animation(.easeInOut(duration: 0.18), value: selectedTab)
    }
}

struct BeansTabBar: View {
    @Binding var selected: BeansTab

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.library, title: "音乐库", icon: "music.note.list", selectedIcon: "music.note.list.fill")
            tabButton(.profile, title: "我的", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill")
        }
        .padding(5)
        .glassEffect(.regular)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
        .padding(.horizontal, 44)
    }

    private func tabButton(_ tab: BeansTab, title: String, icon: String, selectedIcon: String) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.beansAmber : Color.beansSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Color.beansAmber.opacity(0.16) : .clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}