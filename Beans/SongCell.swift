import SwiftUI

struct SongCell: View {
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

    var body: some View {
        HStack(spacing: 12) {
            if showCover {
                CoverImage(url: song.coverURL, size: 46, cornerRadius: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                Text(song.artists.isEmpty ? song.album : song.artists)
                    .font(.system(size: 12))
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
                    Task { _ = try? await auth.toggleLike(song) }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15))
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
                Task { _ = try? await auth.toggleLike(song) }
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