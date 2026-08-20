import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @Binding var showPlayer: Bool

    var body: some View {
        Button {
            showPlayer = true
        } label: {
            HStack(spacing: 12) {
                CoverImage(url: player.currentSong?.coverURL, size: 40, cornerRadius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentSong?.name ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text(player.currentSong?.artists ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .bottom) {
                ProgressLine(progress: player.progress, duration: player.duration)
                    .frame(height: 2.5)
                    .padding(.horizontal, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}