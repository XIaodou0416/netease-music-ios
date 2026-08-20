import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var showPlayer = false

    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 12) {
                BeansCover(url: song.coverURL, cornerRadius: 9)
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
            .padding(.top, 10)
            .padding(.bottom, 9)
            .background(Color.beansGlassFill)   // 玻璃非透明基底，避免糊块
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottom) {
                // 进度条贴底自动对齐（原固定 offset 会在不同字体/尺寸下错位）
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(Color.beansAmber)
                            .frame(width: max(0, geo.size.width * (player.duration > 0 ? player.progress / player.duration : 0)))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .onTapGesture { showPlayer = true }
            .sheet(isPresented: $showPlayer) { PlayerView() }
        }
    }
}