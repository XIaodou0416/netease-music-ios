import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Binding var showPlayer: Bool

    var body: some View {
        let _ = theme.accent
        Button {
            BeansHaptics.tap()
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
                    BeansHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                Button {
                    BeansHaptics.tap()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.78))
                    .overlay {
                        // 液态高光：左上到右下清透玻璃质感
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear, .white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
            .overlay(alignment: .bottom) {
                ProgressLine(progress: player.progress, duration: player.duration)
                    .frame(height: 2.5)
                    .padding(.horizontal, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
        .padding(.horizontal, 12)
    }
}
