import SwiftUI
import MediaPlayer

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var lyrics: [LyricLine] = []
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSleep = false
    @State private var showSimi = false
    @State private var isLiked = false
    @State private var toast: String?

    private let rates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        // sheet 内部独立玻璃采样容器：否则页内 glassEffect 无法采样 → 空白/灰块
        GlassEffectContainer {
            ZStack {
                backgroundBlur
                Color.beansBackground.opacity(0.3).ignoresSafeArea()
                if player.currentSong == nil {
                    emptyFallback
                } else {
                    content
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showQueue) { QueueView() }
        .sheet(isPresented: $showSleep) { SleepTimerSheet() }
        .sheet(isPresented: $showSimi) {
            if let song = player.currentSong {
                SimiSongsSheet(songID: song.id)
            }
        }
        .beansToast(message: $toast)
        .task(id: player.currentSong?.id) {
            loadLyrics()
            isLiked = false
        }
    }

    // MARK: - 主内容（小屏可滚动，避免溢出裁切/空白）

    private var content: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    dragHandle
                    songHeader
                    Spacer(minLength: 8)
                    if showLyrics {
                        lyricsView.frame(height: max(200, min(320, geo.size.height * 0.30)))
                    } else {
                        coverArt(side: min(280, max(180, geo.size.width - 96)))
                    }
                    Spacer(minLength: 8)
                    controlPanel
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height - 24, alignment: .top)
            }
        }
    }

    // MARK: - 兜底视图（无歌曲时不白屏）

    private var emptyFallback: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 52))
                .foregroundStyle(Color.beansSecondary)
            Text("暂无可播放的歌曲")
                .font(.headline)
                .foregroundStyle(Color.beansLabel)
            Text("从歌单或搜索中选择一首歌开始播放")
                .font(.footnote)
                .foregroundStyle(Color.beansSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("关闭")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.beansAmber))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .blur(radius: 90)
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
            .padding(.top, 8)
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
            if let album = player.currentSong?.album, !album.isEmpty {
                Text(album)
                    .font(.caption)
                    .foregroundStyle(Color.beansSecondary.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.beansGlassFill)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func coverArt(side: CGFloat) -> some View {
        Button {
            withAnimation(.snappy) { showLyrics.toggle() }
        } label: {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.isPlaying)) { timeline in
                let angle = timeline.date.timeIntervalSinceReferenceDate * 15
                BeansCover(url: player.currentSong?.coverURL, cornerRadius: 24)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            Button {
                withAnimation(.snappy) { showLyrics.toggle() }
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if lyrics.isEmpty {
                        Text(player.loadFailed ? "加载失败，点下方重试" : "暂无歌词")
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if line.text != "·" {
                                        player.seek(to: line.time)
                                    }
                                }
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

    // MARK: - 控制面板（玻璃容器）

    private var controlPanel: some View {
        VStack(spacing: 12) {
            progressBar

            HStack(spacing: 40) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.title2).foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button { player.togglePlayPause() } label: {
                    ZStack {
                        Circle().fill(Color.beansAmber)
                        Image(systemName: player.isBuffering ? "hourglass" : (player.isPlaying ? "pause.fill" : "play.fill"))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)

                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.title2).foregroundStyle(Color.beansLabel)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 18) {
                controlButton(icon: "gobackward.15", caption: "-15") { player.seekBy(-15) }
                controlButton(icon: player.playMode.icon, caption: player.playMode.title) { player.togglePlayMode() }
                rateMenu
                controlButton(icon: "list.bullet", caption: "队列") { showQueue = true }
                controlButton(icon: "moon.zzz", caption: player.sleepTimerFormatted ?? "定时", tint: player.sleepTimerEndsAt != nil ? Color.beansAmber : nil) { showSleep = true }
                controlButton(icon: "goforward.15", caption: "+15") { player.seekBy(15) }
            }

            HStack(spacing: 18) {
                controlButton(icon: isLiked ? "heart.fill" : "heart", caption: "喜欢", tint: isLiked ? .pink : nil) { toggleLike() }
                if let count = player.playCounts[player.currentSong?.id ?? -1], count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle").font(.system(size: 14))
                        Text("已听 \(count) 次").font(.system(size: 10))
                    }
                    .foregroundStyle(Color.beansSecondary)
                }
                controlButton(icon: "sparkles", caption: "相似") { showSimi = true }
                controlButton(icon: "square.and.arrow.up", caption: "分享") { shareCurrentSong() }
            }

            if player.loadFailed {
                Button {
                    player.retryCurrent()
                } label: {
                    Label("播放失败，点击重试", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
            }

            VolumeSlider()
                .frame(height: 24)
                .padding(.horizontal, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.beansGlassFill)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }

    private func controlButton(icon: String, caption: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(caption)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(tint ?? Color.beansLabel)
        }
        .buttonStyle(.plain)
    }

    private var rateMenu: some View {
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
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.beansLabel)
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
                Text(formatTime(player.progress)).font(.caption2.monospacedDigit()).foregroundStyle(Color.beansSecondary)
                Spacer()
                Text(formatTime(player.duration)).font(.caption2.monospacedDigit()).foregroundStyle(Color.beansSecondary)
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

    private func shareCurrentSong() {
        guard let song = player.currentSong else { return }
        let text = "\(song.name) - \(song.artists)（来自 Beans 分享）"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
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