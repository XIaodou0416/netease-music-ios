import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var lyrics: [LyricLine] = []
    @State private var showQueue = false
    @State private var showSleepTimer = false
    @State private var showSimi = false
    @State private var showAddToPlaylist = false
    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    private var song: Song? { player.currentSong }

    private var progressBinding: Binding<Double> {
        Binding(
            get: { scrubbing ? scrubValue : player.progress },
            set: { scrubValue = $0 }
        )
    }

    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                RotatingCover(isPlaying: player.isPlaying, url: song?.coverURL, size: 260)
                    .padding(.vertical, 20)
                songInfo
                    .padding(.horizontal, 24)
                lyricsArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 128)
                    .padding(.vertical, 10)
                progressArea
                    .padding(.horizontal, 24)
                controlsRow
                    .padding(.top, 18)
                bottomRow
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .foregroundStyle(Color.beansLabel)
        .task(id: song?.id) {
            await loadLyrics()
        }
        .sheet(isPresented: $showQueue) { QueueView().environmentObject(player) }
        .sheet(isPresented: $showSleepTimer) { SleepTimerSheet().environmentObject(player) }
        .sheet(isPresented: $showSimi) { SimiSongsSheet().environmentObject(player).environmentObject(auth) }
        .sheet(isPresented: $showAddToPlaylist) {
            if let song {
                AddToPlaylistSheet(song: song).environmentObject(auth)
            }
        }
    }

    private var background: some View {
        ZStack {
            GlassBackdrop()
            AsyncImage(url: song?.coverURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .opacity(0.45)
                }
            }
            .ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.25), .clear, .black.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.beansSecondary)
                Text(song?.album ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var songInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song?.name ?? "")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                Text(song?.artists ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if auth.isLoggedIn, let song {
                Button {
                    Task { _ = try? await auth.toggleLike(song) }
                } label: {
                    Image(systemName: isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundStyle(isLiked(song) ? Color.beansAmber : Color.beansLabel)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lyricsArea: some View {
        Group {
            if lyrics.isEmpty {
                Text("暂无歌词")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(maxHeight: .infinity)
            } else {
                LyricsSection(lyrics: lyrics)
            }
        }
    }

    private var progressArea: some View {
        VStack(spacing: 6) {
            Slider(
                value: progressBinding,
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        scrubbing = true
                    } else {
                        scrubbing = false
                        player.seek(to: scrubValue)
                    }
                }
            )
            .tint(Color.beansAmber)
            HStack {
                Text(beansTimeString(scrubbing ? scrubValue : player.progress))
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Text(beansTimeString(player.duration))
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundStyle(Color.beansSecondary)
            HStack {
                GlassIconButton(systemName: "gobackward.15", size: 40) {
                    player.seekBy(-15)
                }
                Spacer()
                GlassIconButton(systemName: "goforward.15", size: 40) {
                    player.seekBy(15)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 26) {
            Button {
                player.togglePlayMode()
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 76, height: 76)
                    .glassEffect(.regular, in: .circle)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            }
            .buttonStyle(.plain)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                showQueue = true
            } label: {
                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomRow: some View {
        HStack {
            Menu {
                ForEach(rateOptions, id: \.self) { option in
                    Button {
                        player.setRate(option)
                    } label: {
                        if abs(player.rate - option) < 0.01 {
                            Label(String(format: "%.2gx", option), systemImage: "checkmark")
                        } else {
                            Text(String(format: "%.2gx", option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speedometer")
                    Text(String(format: "%.2gx", player.rate))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(Color.beansSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            }

            Spacer()

            Button {
                showSleepTimer = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: player.sleepTimerRemaining > 0 ? "moon.zzz.fill" : "moon.zzz")
                    if player.sleepTimerRemaining > 0 {
                        Text(player.sleepTimerFormatted ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
                .foregroundStyle(player.sleepTimerRemaining > 0 ? Color.beansAmber : Color.beansSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)

            Button {
                showSimi = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                showAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private func isLiked(_ song: Song) -> Bool {
        auth.favoriteTracks.contains { $0.id == song.id }
    }

    private func loadLyrics() async {
        lyrics = []
        guard let song else { return }
        guard let raw = try? await NetEaseAPI.shared.lyric(id: song.id) else { return }
        lyrics = LyricParser.parse(raw)
    }
}

// MARK: - 旋转封面

struct RotatingCover: View {
    let isPlaying: Bool
    let url: URL?
    var size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let angle = isPlaying
                ? (context.date.timeIntervalSinceReferenceDate * 6).truncatingRemainder(dividingBy: 360)
                : 0
            CoverImage(url: url, size: size, cornerRadius: 28)
                .rotationEffect(.degrees(angle))
        }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}

// MARK: - 歌词（逐行高亮 + 自动滚动）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let lyrics: [LyricLine]

    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let time = player.progress
        return lyrics.lastIndex { $0.time <= time }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: 15, weight: index == currentIndex ? .semibold : .regular))
                            .foregroundStyle(index == currentIndex ? Color.beansAmber : Color.beansSecondary)
                            .multilineTextAlignment(.center)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .onChange(of: currentIndex) { _, newIndex in
                guard let newIndex else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}