import SwiftUI

// 迷你播放器：全局悬浮，点击进入全屏播放器
struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var showPlayer = false

    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 12) {
                BeansCover(url: song.coverURL, radius: 9)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text(song.artists)
                        .font(.caption2)
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isBuffering ? "hourglass" : (player.isPlaying ? "pause.fill" : "play.fill"))
                        .font(.title3)
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.beansGlassFill)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
            .contentShape(Rectangle())
            .onTapGesture { showPlayer = true }
            .sheet(isPresented: $showPlayer) {
                PlayerView()
                    .presentationDragIndicator(.hidden)
            }
        }
    }
}