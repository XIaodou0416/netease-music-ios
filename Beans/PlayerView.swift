import SwiftUI

// MARK: - 全屏播放器（全新架构：沉浸式专辑舞台 + 底部毛玻璃控制坞）
// 说明：本文件为 UI 层整体重写，播放/暂停/切歌/进度/倍速/定时/歌词/评论/收藏等业务调用与旧版完全一致；
// 仅重排视图结构与视觉风格（不修改 PlayerManager / NetEaseAPI / AuthStore 任何逻辑）。

struct PlayerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var lyrics: [LyricLine] = []
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSleepTimer = false
    @State private var showSimi = false
    @State private var showAddToPlaylist = false
    @State private var showComments = false

    private var song: Song? { player.currentSong }
    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    stage
                    controlDeck
                }
            }
            .foregroundStyle(Color.beansLabel)
        }
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
        .sheet(isPresented: $showComments) {
            if let song {
                CommentsSheet(song: song)
            }
        }
        .overlay(alignment: .bottom) {
            ToastView(center: ToastCenter.shared)
        }
    }

    // MARK: - 背景（全屏：主题渐变 + 封面模糊源 + 深浅遮罩 + 静态光斑，零逐帧渲染）

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.beansBackground,
                    Color(uiColor: .beansBackground).opacity(0.88),
                ],
                startPoint: .top, endPoint: .bottom
            )
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.55), .black.opacity(0.16), .black.opacity(0.6)]
                    : [.white.opacity(0.26), .clear, .black.opacity(0.24)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            Circle()
                .fill(Color.beansHighlight.opacity(0.15))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 150, y: -340)
            Circle()
                .fill(Color.beansSage.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -170, y: 380)
        }
        // 封面模糊背景挂在固定全屏容器的 background 层：加载完成不会影响任何布局
        .background {
            if let coverURL = song?.coverURL {
                AsyncImage(url: coverURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .blur(radius: 34)
                            .saturation(1.2)
                            .opacity(0.6)
                            .clipped()
                    }
                }
            }
        }
    }

    // MARK: - 顶栏（左上角收起按钮保留；右侧队列；中部状态，悬浮胶囊风）

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                Text(song?.album ?? "Beans 音乐")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.beansSecondary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Button {
                BeansHaptics.tap()
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: - 中间舞台（封面 / 歌词 / 空态，独立测量保证任何屏幕都不溢出、不错位）

    private var stage: some View {
        GeometryReader { geo in
            if song == nil {
                placeholderView
            } else if showLyrics {
                lyricsPane
            } else {
                albumStage(coverSize: min(280, min(geo.size.width * 0.60, geo.size.height * 0.94)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 专辑舞台（封面居中 + 主题光晕 + 进度光环；点封面切歌词；封面不旋转）

    private func albumStage(coverSize: CGFloat) -> some View {
        let ratio = player.duration > 0 ? min(max(player.progress / player.duration, 0), 1) : 0
        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.beansAccent.opacity(0.28))
                    .frame(width: coverSize * 1.34, height: coverSize * 1.34)
                    .blur(radius: 48)
                Circle()
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.10 : 0.30), lineWidth: 1)
                    .frame(width: coverSize * 1.16, height: coverSize * 1.16)
                Circle()
                    .trim(from: 0, to: max(0.035, ratio))
                    .stroke(LinearGradient.beansAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: coverSize * 1.16, height: coverSize * 1.16)
                Button {
                    toggleLyrics()
                } label: {
                    CoverImage(url: song?.coverURL, size: coverSize, cornerRadius: min(26, coverSize * 0.10))
                        .overlay {
                            RoundedRectangle(cornerRadius: min(26, coverSize * 0.10), style: .continuous)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 26, y: 14)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.95))
            }
            .frame(width: coverSize * 1.34, height: coverSize * 1.34)

            Label("轻点封面查看歌词", systemImage: "quote.bubble")
                .font(.system(size: 11))
                .foregroundStyle(Color.beansSecondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空态兜底（歌曲数据为空时展示，不再出现空白页）

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.beansSecondary)
            Text("暂无播放内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.beansLabel)
            Text("返回选择一首歌曲即可开始播放")
                .font(.system(size: 13))
                .foregroundStyle(Color.beansSecondary)
            Button {
                BeansHaptics.tap()
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 歌词面板（左上角标题 + 左对齐歌词 + 无歌词兜底；切歌强制重建视图刷新布局）

    private var lyricsPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("歌词")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(duration: 0.35)) { showLyrics = false }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.beansSecondary)
                        .frame(width: 32, height: 32)
                        .background { Circle().fill(.ultraThinMaterial) }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.top, 2)
            .padding(.bottom, 8)

            if lyrics.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.beansSecondary.opacity(0.7))
                    Text("暂无歌词")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.beansSecondary)
                    Text("点击封面可返回专辑视图")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.beansSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LyricsSection(lyrics: lyrics) { line in
                    BeansHaptics.tap()
                    player.seek(to: line.time)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id("lyricsPane-\(song?.id ?? -1)")
    }

    // MARK: - 底部控制坞（毛玻璃圆角坞：信息 / 进度 / 主控制 / 工具，四行分区）

    private var controlDeck: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.beansSecondary.opacity(0.5))
                .frame(width: 34, height: 4)
                .padding(.top, 8)

            VStack(spacing: 14) {
                songInfoRow
                progressBlock
                mainControls
                utilityRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 34, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 34,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 1.2)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: .black.opacity(0.16), radius: 22, y: -6)
    }

    // MARK: - 歌曲信息（标题防截断自适应缩字；副标题 歌手 · 专辑；右侧红心）

    private var songInfoRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(song?.name ?? "未在播放")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if auth.isLoggedIn, let song {
                Button {
                    BeansHaptics.tap()
                    likeTapped(song)
                } label: {
                    Image(systemName: isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(isLiked(song) ? Color.beansHighlight : Color.beansLabel)
                        .frame(width: 38, height: 38)
                        .background { Circle().fill(.ultraThinMaterial) }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
        }
    }

    private var subtitle: String {
        guard let song else { return "" }
        let parts = [song.artists, song.album].filter { !$0.isEmpty }
        return parts.isEmpty ? "未知歌曲" : parts.joined(separator: " · ")
    }

    // MARK: - 进度区块（可点按 / 拖动的进度条 + 当前时间 / 总时长 + ±15 秒）

    private var progressBlock: some View {
        VStack(spacing: 4) {
            SeekBar()
            HStack(spacing: 8) {
                seekPillButton("gobackward.15") { player.seekBy(-15) }
                Text(beansTimeString(player.progress))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(minWidth: 36, alignment: .leading)
                Spacer(minLength: 0)
                Text(beansTimeString(player.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(minWidth: 36, alignment: .trailing)
                seekPillButton("goforward.15") { player.seekBy(15) }
            }
        }
    }

    private func seekPillButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.beansSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    // MARK: - 主控制行（定时 / 循环 / 上一曲 / 播放暂停 / 下一曲 / 评论，尺寸统一水平居中）

    private var mainControls: some View {
        HStack(spacing: 0) {
            deckButton(icon: player.playMode.icon, accent: player.playMode == .shuffle) {
                player.togglePlayMode()
                BeansHaptics.select()
            }
            deckButton(icon: "backward.fill") {
                BeansHaptics.tap()
                player.previous()
            }
            playButton
            deckButton(icon: "forward.fill") {
                BeansHaptics.tap()
                player.next()
            }
            deckButton(icon: "bubble.left.and.bubble.right") {
                BeansHaptics.tap()
                showComments = true
            }
        }
    }

    private func deckButton(icon: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(accent ? Color.beansHighlight : Color.beansLabel)
                .frame(width: 46, height: 46)
                .background { Circle().fill(.ultraThinMaterial) }
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
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(width: 62, height: 62)
                .background {
                    Circle()
                        .fill(LinearGradient.beansAccent)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        }
                }
                .clipShape(Circle())
                .shadow(color: Color.beansHighlight.opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        .frame(maxWidth: .infinity)
    }

    // MARK: - 工具行（倍速左下角；歌词开关；更多菜单收纳相似歌曲 / 添加到歌单）

    private var utilityRow: some View {
        HStack(spacing: 10) {
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
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: "%.2gx", player.rate))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(Color.beansSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                toggleLyrics()
            } label: {
                Label(showLyrics ? "收起歌词" : "歌词", systemImage: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(showLyrics ? Color.beansHighlight : Color.beansSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .clipShape(Capsule())
            }
            .buttonStyle(GlassPressButtonStyle())

            Menu {
                Button {
                    showSleepTimer = true
                } label: {
                    Label(player.sleepTimerRemaining > 0 ? "定时关闭（进行中）" : "定时关闭", systemImage: "moon.zzz")
                }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 36, height: 36)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 动作

    private func toggleLyrics() {
        withAnimation(.spring(duration: 0.4)) {
            showLyrics.toggle()
        }
    }

    private func isLiked(_ song: Song) -> Bool {
        auth.favoriteTracks.contains { $0.id == song.id }
    }

    private func likeTapped(_ song: Song) {
        guard auth.isLoggedIn else {
            ToastCenter.shared.show("请先登录后再收藏")
            return
        }
        let willLike = !auth.isLiked(song)
        Task {
            do {
                let ok = try await auth.toggleLike(song)
                ToastCenter.shared.show(ok
                    ? (willLike ? "已收藏到「我喜欢的音乐」" : "已取消收藏")
                    : "收藏失败，请稍后再试")
            } catch {
                ToastCenter.shared.show("收藏失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadLyrics() async {
        lyrics = []
        guard let song else { return }
        guard let raw = try? await NetEaseAPI.shared.lyric(id: song.id) else { return }
        lyrics = LyricParser.parse(raw)
    }
}

// MARK: - 自定义进度条（点击 / 拖动均可跳转，拇指跟随主题色）

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
            let thumbX = min(max(width * ratio, 9), max(width - 9, 9))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.beansSecondary.opacity(0.3))
                    .frame(height: 5)
                Capsule()
                    .fill(LinearGradient.beansAccent)
                    .frame(width: thumbX, height: 5)
                Circle()
                    .fill(Color.beansHighlight)
                    .frame(width: 15, height: 15)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: thumbX - 7.5)
            }
            .frame(width: width, height: 30)
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
        .frame(height: 30)
    }
}

// MARK: - 歌词（左对齐 + 左右安全边距 + 逐行高亮 + 自动滚动 + 点击跳转；容器显式撑满宽度防排版错位）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let lyrics: [LyricLine]
    let onTapLine: (LyricLine) -> Void

    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        return lyrics.lastIndex { $0.time <= player.progress }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .top, spacing: 10) {
                            Capsule()
                                .fill(index == currentIndex ? Color.beansHighlight : Color.clear)
                                .frame(width: 3, height: 16)
                                .padding(.top, 4)
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: index == currentIndex ? 16 : 14,
                                              weight: index == currentIndex ? .bold : .regular))
                                .foregroundStyle(index == currentIndex ? Color.beansHighlight : Color.beansSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { onTapLine(line) }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToCurrent(proxy)
            }
            .onChange(of: currentIndex) { _, newIndex in
                guard let newIndex else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let currentIndex else { return }
        proxy.scrollTo(currentIndex, anchor: .center)
    }
}
