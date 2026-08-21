import SwiftUI

struct SongCell: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    let song: Song
    var showCover = true
    var onTap: (() -> Void)?

    @State private var showAddToPlaylist = false

    private var isCurrent: Bool {
        player.currentSong?.identityKey == song.identityKey
    }

    var body: some View {
        let _ = theme.accent
        HStack(spacing: 12) {
            if showCover {
                CoverImage(url: song.coverURL, size: 46, cornerRadius: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(BeansFont.appFont(15, isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                Text(song.artists.isEmpty ? song.album : song.artists)
                    .font(BeansFont.appFont(12))
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
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
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
