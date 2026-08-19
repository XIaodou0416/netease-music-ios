import SwiftUI

enum BeansTab: Hashable {
    case library
    case profile
}

struct RootView: View {
    @State private var selectedTab: BeansTab = .library

    var body: some View {
        ZStack {
            Color.beansBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .library:
                    LibraryView(tab: $selectedTab)
                case .profile:
                    ProfileView(tab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 底部液态玻璃栏（迷你播放器 + 可长按滑动的标签栏）

struct BeansBottomBar: View {
    @Binding var selected: BeansTab
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        VStack(spacing: 10) {
            if player.currentSong != nil {
                MiniPlayerBar()
            }
            BeansTabBar(selected: $selected)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct BeansTabBar: View {
    @Binding var selected: BeansTab

    @State private var barSize: CGSize = .zero
    @State private var dragRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.library, title: "音乐库", icon: "music.note.list", selectedIcon: "music.note.list.fill")
            tabButton(.profile, title: "我的", icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill")
        }
        .padding(7)
        .background(barBackground)
        .overlay { slidingPill }
        .contentShape(Capsule())
        .gesture(slideGesture)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: selected)
        .padding(.horizontal, 26)
        .sensoryFeedback(.impact(weight: .light), trigger: selected)
    }

    // MARK: - 外观

    private var barBackground: some View {
        GeometryReader { geo in
            Capsule()
                // 修复：原实现 fill(Color.clear) + glassEffect 导致玻璃无内容可采样，
                // 表现为模糊失效/渲染糊块。改用半透明动态基底色，玻璃效果可正常采样背景。
                .fill(Color.beansGlassFill)
                .glassEffect(.regular)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
                .onAppear { barSize = geo.size }
                .onChange(of: geo.size) { _, newSize in barSize = newSize }
        }
    }

    private var slidingPill: some View {
        GeometryReader { geo in
            let width = max((geo.size.width - 14) / 2, 1)
            let height = max(geo.size.height - 14, 1)
            let bias: CGFloat = selected == .profile ? 1 : 0
            let t = min(max(bias + dragRatio, 0), 1)
            Capsule()
                .fill(Color.beansAmber.opacity(0.18))
                .overlay(
                    Capsule().strokeBorder(Color.beansAmber.opacity(0.28), lineWidth: 1)
                )
                .frame(width: width, height: height)
                .offset(x: 7 + t * width, y: 7)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 长按滑动交互

    private var slideGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    isDragging = true
                case .second(true, let drag):
                    if let drag {
                        let half = max(barSize.width / 2, 1)
                        dragRatio = drag.translation.width / half
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                guard isDragging else { return }
                let threshold: CGFloat = 0.28
                if dragRatio > threshold {
                    selected = .profile
                } else if dragRatio < -threshold {
                    selected = .library
                }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                    isDragging = false
                    dragRatio = 0
                }
            }
    }

    private func tabButton(_ tab: BeansTab, title: String, icon: String, selectedIcon: String) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.beansAmber : Color.beansSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
