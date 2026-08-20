import SwiftUI

struct SongCell: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    let song: Song
    var showCover = true
    var showLike = true
    var onTap: (() -> Void)?

    @State private var showAddToPlaylist = false

    private var isCurrent: Bool {
        player.currentSong?.id == song.id
    }

    private var isLiked: Bool {
        auth.favoriteTracks.contains { $0.id == song.id }
    }

    private func likeTapped() {
        guard auth.isLoggedIn else {
            ToastCenter.shared.show("请先登录后再收藏")
            return
        }
        let willLike = !auth.isLiked(song)
        Task {
            do {
                let ok = try await auth.toggleLike(song)
                ToastCenter.shared.show(ok
                    ? (willLike ? "已收藏到「我喜欢的音乐」" : "已取消收藏")
                    : "收藏失败，请稍后再试")
            } catch {
                ToastCenter.shared.show("收藏失败：\(error.localizedDescription)")
            }
        }
    }

    var body: some View {
        let _ = theme.accent
        HStack(spacing: 12) {
            if showCover {
                CoverImage(url: song.coverURL, size: 46, cornerRadius: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.custom(BeansFont.name, size: 15).weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                Text(song.artists.isEmpty ? song.album : song.artists)
                    .font(.custom(BeansFont.name, size: 12))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isCurrent && player.isPlaying {
                NowPlayingIndicator()
            } else {
                Text(song.formattedDuration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.beansSecondary)
            }
            if showLike {
                Button {
                    BeansHaptics.tap()
                    likeTapped()
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.custom(BeansFont.name, size: 15))
                        .foregroundStyle(isLiked ? Color.beansAmber : Color.beansSecondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button {
                BeansHaptics.tap()
                likeTapped()
            } label: {
                Label(isLiked ? "取消收藏" : "收藏", systemImage: isLiked ? "heart.slash" : "heart")
            }
            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                showAddToPlaylist = true
            } label: {
                Label("添加到歌单", systemImage: "text.badge.plus")
            }
            if !isCurrent {
                Button {
                    if let index = player.queue.firstIndex(of: song) {
                        player.playQueueIndex(index)
                    }
                } label: {
                    Label("立即播放", systemImage: "play.fill")
                }
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(song: song)
                .environmentObject(auth)
        }
    }
}
