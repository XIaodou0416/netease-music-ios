import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var showPlayer = false

    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 12) {
                AsyncImage(url: song.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.beansCard
                }
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

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
                Spacer()
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isBuffering ? "hourglass" : (player.isPlaying ? "pause.fill" : "play.fill"))
                        .font(.title3)
                        .foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.clear)
                        Rectangle()
                            .fill(Color.beansAmber)
                            .frame(width: max(0, geo.size.width * (player.duration > 0 ? player.progress / player.duration : 0)))
                    }
                }
                .frame(height: 2)
                .offset(y: 21)
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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