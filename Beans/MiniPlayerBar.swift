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
                    Color.white.opacity(0.08)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name).font(.subheadline).foregroundStyle(Color.beansCream).lineLimit(1)
                    Text(song.artists).font(.caption2).foregroundStyle(Color.beansMuted).lineLimit(1)
                }
                Spacer()
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Color.beansCream)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .onTapGesture { showPlayer = true }
            .sheet(isPresented: $showPlayer) { PlayerView() }
        }
    }
}