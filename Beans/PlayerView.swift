import SwiftUI

// MARK: - 全屏播放器（网易云风格：毛玻璃背景 + 上半区居中封面 + 歌名居中 + 进度条 + 主控制行）

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("beans.accent") private var accentRaw = ""

    @State private var lyrics: [LyricLine] = []
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSleepTimer = false
    @State private var showSimi = false
    @State private var showAddToPlaylist = false
    @State private var showComments = false
    @State private var dragOffset: CGFloat = 0

    private var song: Song? { player.currentSong }
    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        GeometryReader { geo in
            let coverSize = min(264, max(200, geo.size.height * 0.30))
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    if song == nil {
                        // 空态兜底：歌曲数据为空时展示占位视图，避免偶发空白页
                        placeholderView
                    } else if showLyrics {
                        lyricsPane
                    } else {
                        VStack(spacing: 0) {
                            Spacer(minLength: 24)
                            coverButton(size: coverSize)
                            Spacer(minLength: 18)
                            songInfo
                            Spacer(minLength: 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    SeekBar()
                        .padding(.horizontal, 30)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    timeRow
                        .padding(.horizontal, 30)
                        .padding(.bottom, 20)

                    controlsRow
                        .padding(.bottom, 18)

                    bottomRow
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: dragOffset)
                .opacity(1 - min(max(dragOffset, 0) / 480, 0.6))
            }
            .foregroundStyle(Color.beansLabel)
        }
        .task(id: song?.id) {
            await loadLyrics()
        }
        .onAppear {
            dragOffset = 0
        }
        .sheet(isPresented: $showQueue) { QueueView().environmentObject(player) }
        .sheet(isPresented: $showSleepTimer) { SleepTimerSheet().environmentObject(player) }
        .sheet(isPresented: $showSimi) { SimiSongsSheet().environmentObject(player).environmentObject(auth) }
        .sheet(isPresented: $showAddToPlaylist) {
            if let song {
                AddToPlaylistSheet(song: song).environmentObject(auth)
            }
        }
        .sheet(isPresented: $showComments) {
            if let song {
                CommentsSheet(song: song)
            }
        }
    }

    // MARK: - 背景（全屏毛玻璃模糊：专辑图作模糊源，深浅模式自适应遮罩 + 配色光斑）

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.beansBackground,
                    Color(uiColor: .beansBackground).opacity(0.85),
                ],
                startPoint: .top, endPoint: .bottom
            )
            if let coverURL = song?.coverURL {
                AsyncImage(url: coverURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 32)
                            .saturation(1.25)
                            .opacity(0.62)
                    }
                }
                .ignoresSafeArea()
            }
            // 深浅模式遮罩：暗色下拉深、浅色下拉浅，保证前景文字清晰
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.55), .black.opacity(0.18), .black.opacity(0.62)]
                    : [.white.opacity(0.28), .clear, .black.opacity(0.22)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            // 配色光斑
            Circle()
                .fill(Color.beansHighlight.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 150, y: -320)
            Circle()
                .fill(Color.beansSage.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -160, y: 360)
        }
    }

    // MARK: - 下滑退出

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 150 || value.predictedEndTranslation.height > 320 {
                    BeansHaptics.medium()
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.35)) { dragOffset = 0 }
                }
            }
    }

    // MARK: - 顶栏（左上角下拉收起按钮保留）

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                Text(song?.album ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    // MARK: - 空态兜底视图

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Color.beansSecondary)
            Text("暂无播放内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.beansLabel)
            Text("返回后选择一首歌曲即可开始播放")
                .font(.system(size: 13))
                .foregroundStyle(Color.beansSecondary)
            Button {
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(GlassPressButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 封面（居中于页面上半部分，点击切换歌词）

    private func coverButton(size: CGFloat) -> some View {
        Button {
            toggleLyrics()
        } label: {
            CoverImage(url: song?.coverURL, size: size, cornerRadius: min(30, size * 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: min(30, size * 0.12), style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 26, y: 14)
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("歌词")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .clipShape(Capsule())
                    .padding(10)
                }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
        .frame(maxWidth: .infinity)
    }

    // MARK: - 歌曲信息（居中；歌名最多两行 + 自动缩字防截断）

    private var songInfo: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(song?.name ?? "")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(song?.artists ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 60)

            if auth.isLoggedIn, let song {
                Button {
                    BeansHaptics.tap()
                    Task { _ = try? await auth.toggleLike(song) }
                } label: {
                    Image(systemName: isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 19))
                        .foregroundStyle(isLiked(song) ? Color.beansHighlight : Color.beansLabel)
                        .frame(width: 42, height: 42)
                        .background {
                            Circle().fill(.ultraThinMaterial)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - 歌词

    private var lyricsPane: some View {
        VStack(spacing: 8) {
            HStack {
                Text("歌词")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.35)) { showLyrics = false }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansSecondary)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(.ultraThinMaterial)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.horizontal, 24)

            if lyrics.isEmpty {
                Text("暂无歌词")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LyricsSection(lyrics: lyrics) { line in
                    BeansHaptics.tap()
                    player.seek(to: line.time)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .padding(.top, 6)
    }

    // MARK: - 时间行（±15 秒在两端，时间贴近进度条，上下留安全边距）

    private var timeRow: some View {
        HStack(spacing: 10) {
            seekPillButton("gobackward.15") { player.seekBy(-15) }
            Text(beansTimeString(player.progress))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.beansSecondary)
                .frame(minWidth: 38, alignment: .leading)
            Spacer(minLength: 0)
            Text(beansTimeString(player.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.beansSecondary)
                .frame(minWidth: 38, alignment: .trailing)
            seekPillButton("goforward.15") { player.seekBy(15) }
        }
    }

    private func seekPillButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.beansSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    // MARK: - 主控制行（定时 / 循环模式 / 上一曲 / 播放暂停 / 下一曲，尺寸统一、水平均匀居中）

    private var controlsRow: some View {
        HStack(spacing: 0) {
            controlButton(icon: player.sleepTimerRemaining > 0 ? "moon.zzz.fill" : "moon.zzz",
                          accent: player.sleepTimerRemaining > 0) {
                showSleepTimer = true
            }
            controlButton(icon: player.playMode.icon, accent: player.playMode == .shuffle) {
                player.togglePlayMode()
                BeansHaptics.select()
            }
            controlButton(icon: "backward.fill") {
                BeansHaptics.tap()
                player.previous()
            }
            playButton
            controlButton(icon: "forward.fill") {
                BeansHaptics.tap()
                player.next()
            }
        }
        .padding(.horizontal, 10)
    }

    private func controlButton(icon: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(accent ? Color.beansHighlight : Color.beansLabel)
                .frame(width: 52, height: 52)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
        .frame(maxWidth: .infinity)
    }

    private var playButton: some View {
        Button {
            BeansHaptics.tap()
            player.togglePlayPause()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(width: 72, height: 72)
                .background {
                    Circle()
                        .fill(LinearGradient.beansAccent)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        }
                }
                .clipShape(Circle())
                .shadow(color: Color.beansHighlight.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.92))
        .frame(maxWidth: .infinity)
    }

    // MARK: - 底部功能行（倍速固定在左下角，其余功能靠右，功能全部保留）

    private var bottomRow: some View {
        HStack {
            Menu {
                ForEach(rateOptions, id: \.self) { option in
                    Button {
                        player.setRate(option)
                        BeansHaptics.select()
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
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                BeansHaptics.tap()
                showComments = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Button {
                BeansHaptics.tap()
                toggleLyrics()
            } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(showLyrics ? Color.beansHighlight : Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Menu {
                Button {
                    showSimi = true
                } label: {
                    Label("相似歌曲", systemImage: "sparkles")
                }
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("添加到歌单", systemImage: "text.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
    }

    private func toggleLyrics() {
        withAnimation(.spring(duration: 0.4)) {
            showLyrics.toggle()
        }
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

// MARK: - 自定义进度条（点按 / 拖动均可跳转）

struct SeekBar: View {
    @EnvironmentObject private var player: PlayerManager

    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    private var progress: Double {
        scrubbing ? scrubValue : player.progress
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = max(player.duration, 1)
            let ratio = min(max(progress / total, 0), 1)
            let thumbX = min(max(width * ratio, 8), max(width - 8, 8))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.beansSecondary.opacity(0.28))
                    .frame(height: 5)
                Capsule()
                    .fill(LinearGradient.beansAccent)
                    .frame(width: thumbX, height: 5)
                Circle()
                    .fill(Color.beansHighlight)
                    .frame(width: 15, height: 15)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: thumbX - 7.5)
            }
            .frame(width: width, height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        scrubbing = true
                        scrubValue = min(max(value.location.x / width, 0), 1) * total
                    }
                    .onEnded { _ in
                        BeansHaptics.tap()
                        player.seek(to: scrubValue)
                        scrubbing = false
                    }
            )
        }
        .frame(height: 32)
    }
}

// MARK: - 歌词（逐行高亮 + 自动滚动 + 点击跳转）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let lyrics: [LyricLine]
    let onTapLine: (LyricLine) -> Void

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
                            .foregroundStyle(index == currentIndex ? Color.beansHighlight : Color.beansSecondary)
                            .multilineTextAlignment(.center)
                            .id(index)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapLine(line)
                            }
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