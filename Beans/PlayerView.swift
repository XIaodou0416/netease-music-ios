import SwiftUI
import MediaPlayer

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @State private var lyrics: [LyricLine] = []
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSleep = false
    @State private var isLiked = false
    @State private var toast: String?

    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack {
            backgroundBlur
            Color.beansBackground.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 0) {
                dragHandle
                songHeader
                Spacer(minLength: 12)

                if showLyrics {
                    lyricsView
                        .frame(height: 340)
                } else {
                    coverArt
                }

                Spacer(minLength: 12)
                controls
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showQueue) { QueueView() }
        .sheet(isPresented: $showSleep) { SleepTimerSheet() }
        .beansToast(message: $toast)
        .task(id: player.currentSong?.id) {
            loadLyrics()
            isLiked = false
        }
    }

    // MARK: - 视觉

    private var backgroundBlur: some View {
        Group {
            if let song = player.currentSong, let url = song.coverURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.beansBackground
                }
                .blur(radius: 80)
                .opacity(0.5)
                .ignoresSafeArea()
            } else {
                Color.beansBackground.ignoresSafeArea()
            }
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.primary.opacity(0.25))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var songHeader: some View {
        VStack(spacing: 4) {
            Text(player.currentSong?.name ?? "")
                .font(.headline)
                .foregroundStyle(Color.beansLabel)
                .lineLimit(1)
            Text(player.currentSong?.artists ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.beansSecondary)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

    private var coverArt: some View {
        Button {
            withAnimation(.snappy) { showLyrics.toggle() }
        } label: {
            AsyncImage(url: player.currentSong?.coverURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.beansCard
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .glassEffect(.regular)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if lyrics.isEmpty {
                        Text("暂无歌词")
                            .font(.subheadline)
                            .foregroundStyle(Color.beansSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                            Text(line.text.isEmpty ? "·" : line.text)
                                .font(.system(size: 17, weight: index == currentLyricIndex ? .semibold : .regular))
                                .foregroundStyle(index == currentLyricIndex ? Color.beansLabel : Color.beansSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .id(index)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .onChange(of: currentLyricIndex) { _, newIndex in
                guard let newIndex else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private var currentLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let p = player.progress
        var index: Int?
        for (i, line) in lyrics.enumerated() where line.time <= p {
            index = i
        }
        return index
    }

    // MARK: - 控制

    private var controls: some View {
        VStack(spacing: 14) {
            progressBar

            HStack(spacing: 44) {
                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(Color.beansAmber)
                        Image(systemName: player.isBuffering ? "hourglass" : (player.isPlaying ? "pause.fill" : "play.fill"))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                    .frame(width: 68, height: 68)
                }
                .buttonStyle(.plain)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 30) {
                Button {
                    player.togglePlayMode()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: player.playMode.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(player.playMode.title)
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(rates, id: \.self) { rate in
                        Button {
                            player.setRate(rate)
                        } label: {
                            if rate == player.rate {
                                Label("\(rate, specifier: "%.2g")x", systemImage: "checkmark")
                            } else {
                                Text("\(rate, specifier: "%.2g")x")
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 16, weight: .semibold))
                        Text("\(player.rate, specifier: "%.2g")x")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.beansLabel)
                }

                Button {
                    showQueue = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .semibold))
                        Text("队列")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)

                Button {
                    showSleep = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 16, weight: .semibold))
                        Text(player.sleepTimerFormatted ?? "定时")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(player.sleepTimerEndsAt != nil ? Color.beansAmber : Color.beansLabel)
                }
                .buttonStyle(.plain)

                Button {
                    toggleLike()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                        Text("喜欢")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(isLiked ? Color.pink : Color.beansLabel)
                }
                .buttonStyle(.plain)
            }

            VolumeSlider()
                .frame(height: 26)
                .padding(.horizontal, 8)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { player.progress },
                    set: { player.progress = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if !editing { player.seek(to: player.progress) }
                }
            )
            .tint(Color.beansAmber)
            HStack {
                Text(formatTime(player.progress))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.beansSecondary)
                Spacer()
                Text(formatTime(player.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.beansSecondary)
            }
        }
    }

    // MARK: - 逻辑

    private func loadLyrics() {
        lyrics = []
        guard let song = player.currentSong else { return }
        Task {
            if let raw = try? await NetEaseAPI.shared.lyric(id: song.id) {
                await MainActor.run { self.lyrics = LyricParser.parse(raw) }
            }
        }
    }

    private func toggleLike() {
        guard let song = player.currentSong else { return }
        isLiked.toggle()
        Task {
            let ok = (try? await NetEaseAPI.shared.like(id: song.id, liked: isLiked)) ?? false
            if !ok {
                await MainActor.run {
                    self.isLiked.toggle()
                    self.toast = "操作失败，请确认已登录"
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// 系统音量滑杆
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}