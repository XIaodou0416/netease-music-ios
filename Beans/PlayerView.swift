import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ZStack {
            if let song = player.currentSong, let url = song.coverURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.black
                }
                .blur(radius: 80)
                .opacity(0.55)
                .ignoresSafeArea()
            } else {
                Color.beansBackground.ignoresSafeArea()
            }
            Color.beansBackground.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Spacer()

                if let song = player.currentSong {
                    AsyncImage(url: song.coverURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .glassEffect(.regular)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )

                    VStack(spacing: 6) {
                        Text(song.name)
                            .font(.title2.bold())
                            .foregroundStyle(.beansCream)
                            .lineLimit(1)
                        Text(song.artists)
                            .font(.subheadline)
                            .foregroundStyle(.beansMuted)
                            .lineLimit(1)
                    }
                }

                VStack(spacing: 8) {
                    Slider(
                        value: $player.progress,
                        in: 0...max(player.duration, 1),
                        onEditingChanged: { editing in
                            if !editing { player.seek(to: player.progress) }
                        }
                    )
                    .tint(.beansAmber)
                    HStack {
                        Text(formatTime(player.progress))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.beansMuted)
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.beansMuted)
                    }
                }

                HStack(spacing: 48) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .onTapGesture { player.previous() }
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 68))
                            .foregroundStyle(.beansAmber)
                    }
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .onTapGesture { player.next() }
                }
                .foregroundStyle(.beansCream)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}