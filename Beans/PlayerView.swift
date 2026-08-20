import SwiftUI
import UIKit
import MediaPlayer

// MARK: - 全屏播放器（Apple Music 风格：封面动态取色 + 封面飞行歌词视图 + 液态玻璃控制坞）
// 说明：本文件为 UI 层整体重写，播放/暂停/切歌/进度/倍速/定时/歌词/评论/收藏等业务调用与旧版完全一致；
// 不修改 PlayerManager / NetEaseAPI / AuthStore 任何逻辑；新增封面主色提取（CoverPalette.swift）。
// 布局说明：封面始终使用固定尺寸 CoverImage（AsyncImage 只渲染在 overlay 中），
// 位置由 position 驱动、随 showLyrics 平滑移动缩放，从根源上避免"封面加载后布局错乱"。

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

    /// 封面图片：仅用于背景毛玻璃与主色提取（不参与封面卡片布局，避免加载后布局变化）
    @State private var coverImage: UIImage?
    /// 封面主色：无封面或加载中为 nil → 回退全局主题色
    @State private var dominant: RGBColor?

    private var song: Song? { player.currentSong }
    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// 动态调色板：背景渐变 / 按钮高亮 / 进度条 / 文字强调全部跟随封面主色
    private var palette: CoverPalette {
        CoverPalette.make(dominant: dominant, colorScheme: colorScheme)
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    stage(geo: geo)
                    controlDeck
                }
                .foregroundStyle(palette.text)
            }
        }
        .task(id: song?.identityKey) {
            await loadLyrics()
            await loadCover()
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

    // MARK: - 背景（封面主色渐变 + 封面毛玻璃模糊 + 深浅遮罩 + 主题光斑，零逐帧渲染）

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 46)
                    .saturation(1.12)
                    .opacity(colorScheme == .dark ? 0.44 : 0.58)
                    .clipped()
            }
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.52), .black.opacity(0.14), .black.opacity(0.55)]
                    : [.white.opacity(0.18), .clear, .black.opacity(0.22)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(palette.accent.opacity(0.16))
                .frame(width: 380, height: 380)
                .blur(radius: 110)
                .offset(x: 150, y: -330)
            Circle()
                .fill(palette.accent.opacity(0.10))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -170, y: 380)
        }
    }

    // MARK: - 顶栏（收起 / 状态 / 红心 / 队列）

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                Text(song?.album ?? "Beans 音乐")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            if auth.isLoggedIn, let song {
                Button {
                    BeansHaptics.tap()
                    likeTapped(song)
                } label: {
                    Image(systemName: isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isLiked(song) ? palette.accent : palette.text)
                        .frame(width: 38, height: 38)
                        .background { Circle().fill(.ultraThinMaterial) }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }

            Button {
                BeansHaptics.tap()
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 38, height: 38)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 中间舞台（同一封面视图随 showLyrics 平移缩放；歌词内容淡入；无几何匹配，布局恒定）

    private func stage(geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            if song == nil {
                placeholderView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if showLyrics {
                    lyricsContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }
                coverButton(geo: geo)
                if !showLyrics {
                    albumInfo(geo: geo)
                        .transition(.opacity)
                    Label("轻点封面查看歌词", systemImage: "quote.bubble")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondary.opacity(0.9))
                        .position(x: geo.size.width / 2, y: max(geo.size.height - 44, 44))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showLyrics)
    }

    /// 封面尺寸：专辑模式大图（居中偏上），歌词模式左上角小图
    private func coverSize(in geo: GeometryProxy) -> CGFloat {
        min(300, min(geo.size.width * 0.62, geo.size.height * 0.48))
    }

    /// 封面按钮：始终同一视图（CoverImage 固定尺寸），只改 frame 与 position
    private func coverButton(geo: GeometryProxy) -> some View {
        let size = showLyrics ? 54.0 : coverSize(in: geo)
        let radius = showLyrics ? 13.0 : min(26, size * 0.09)
        return Button {
            toggleLyrics()
        } label: {
            ZStack {
                if !showLyrics {
                    Circle()
                        .fill(palette.accent.opacity(0.22))
                        .frame(width: size * 1.30, height: size * 1.30)
                        .blur(radius: 46)
                    Circle()
                        .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
                        .frame(width: size * 1.12, height: size * 1.12)
                }
                CoverImage(url: song?.coverURL, size: size, cornerRadius: radius)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.96))
        .position(
            x: showLyrics ? 20 + size / 2 : geo.size.width / 2,
            y: showLyrics ? 20 + size / 2 : geo.size.height * 0.40
        )
    }

    /// 专辑模式：封面下方居中歌名 / 歌手（防截断自适应缩字）
    private func albumInfo(geo: GeometryProxy) -> some View {
        let size = coverSize(in: geo)
        return VStack(spacing: 6) {
            Text(song?.name ?? "未在播放")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 32)
        .position(x: geo.size.width / 2, y: geo.size.height * 0.40 + size / 2 + 36)
    }
    /// 歌词模式：封面飞走后顶部保留歌名信息条 + 居中歌词
    private var lyricsContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 与左上角封面（20,20 处 54x54）占位对齐，避免信息条与封面重叠
                Color.clear
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song?.name ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Text(song?.artists ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    toggleLyrics()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(.ultraThinMaterial) }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)

            if lyrics.isEmpty {
                emptyLyricsView
            } else {
                LyricsSection(lyrics: lyrics, accent: palette.accent, secondary: palette.secondary) { line in
                    BeansHaptics.tap()
                    player.seek(to: line.time)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id("lyricsContent-\(song?.identityKey ?? "none")")
    }

    // MARK: - 空态兜底（歌曲数据为空时不出现空白页）

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(palette.secondary)
            Text("暂无播放内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.text)
            Text("返回选择一首歌曲即可开始播放")
                .font(.system(size: 13))
                .foregroundStyle(palette.secondary)
            Button {
                BeansHaptics.tap()
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空歌词兜底

    private var emptyLyricsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(palette.secondary.opacity(0.7))
            Text("暂无歌词")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
            Text("点击左上角封面返回专辑视图")
                .font(.system(size: 11))
                .foregroundStyle(palette.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部控制坞（液态玻璃圆角坞：进度 / 主控制 / 工具+音量）

    private var controlDeck: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(palette.secondary.opacity(0.4))
                .frame(width: 34, height: 4)
                .padding(.top, 8)

            VStack(spacing: 12) {
                progressBlock
                mainControls
                utilityRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background {
            GlassEffectContainer {
                UnevenRoundedRectangle(
                    topLeadingRadius: 34, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 34,
                    style: .continuous
                )
                .fill(.clear)
                .glassEffect(.clear, in: UnevenRoundedRectangle(
                    topLeadingRadius: 34, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 34,
                    style: .continuous
                ))
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 1.2)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .shadow(color: .black.opacity(0.18), radius: 22, y: -6)
    }

    private var subtitle: String {
        guard let song else { return "" }
        let parts = [song.artists, song.album].filter { !$0.isEmpty }
        return parts.isEmpty ? "未知歌曲" : parts.joined(separator: " · ")
    }

    // MARK: - 进度区块（可点按 / 拖动的进度条 + 当前时间 / 总时长 + ±15 秒）
    private var progressBlock: some View {
        VStack(spacing: 2) {
            SeekBar(accent: palette.accent, track: palette.secondary.opacity(0.3))
            HStack(spacing: 6) {
                seekPillButton("gobackward.15") { player.seekBy(-15) }
                Text(beansTimeString(player.progress))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .frame(minWidth: 34, alignment: .leading)
                Spacer(minLength: 0)
                Text(beansTimeString(player.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.secondary)
                    .frame(minWidth: 34, alignment: .trailing)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    // MARK: - 主控制行（循环 / 上一曲 / 播放暂停 / 下一曲 / 评论，尺寸统一水平居中）

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
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accent ? palette.accent : palette.text)
                .frame(width: 44, height: 44)
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
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 58, height: 58)
                .background {
                    Circle()
                        .fill(LinearGradient(
                            colors: [palette.accent, palette.accentSoft],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        }
                }
                .clipShape(Circle())
                .shadow(color: palette.accent.opacity(0.4), radius: 14, y: 7)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        .frame(maxWidth: .infinity)
    }

    // MARK: - 工具行（倍速 / 系统音量条 / 歌词开关 / 更多菜单收纳定时等次要功能）
    private var utilityRow: some View {
        HStack(spacing: 8) {
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
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(format: "%.2gx", player.rate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
            }

            SystemVolumeSlider(tint: palette.accent)
                .frame(maxWidth: .infinity, maxHeight: 22)

            Button {
                toggleLyrics()
            } label: {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(showLyrics ? palette.accent : palette.secondary)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(.ultraThinMaterial) }
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 动作

    private func toggleLyrics() {
        BeansHaptics.tap()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            showLyrics.toggle()
        }
    }

    private func isLiked(_ song: Song) -> Bool {
        auth.favoriteTracks.contains { $0.identityKey == song.identityKey }
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
        var raw: String?
        if song.source == .qq, let mid = song.qqMid {
            raw = try? await QQMusicAPI.shared.lyric(songmid: mid)
        } else {
            raw = try? await NetEaseAPI.shared.lyric(id: song.id)
        }
        guard let raw else { return }
        lyrics = LyricParser.parse(raw)
    }

    // MARK: - 封面加载与主色提取（仅用于背景与取色；封面卡片不受影响，布局恒定）

    private func loadCover() async {
        coverImage = nil
        guard let coverURL = song?.coverURL else {
            dominant = nil
            return
        }
        do {
            let data = try await fetchCover(coverURL)
            guard !Task.isCancelled, let img = UIImage(data: data) else { return }
            coverImage = img
            let rgb = PaletteExtractor.dominantColor(in: img)
            guard !Task.isCancelled else { return }
            // 切歌/封面变化：旧主色保留到新主色就绪，平滑过渡到新配色
            withAnimation(.easeInOut(duration: 0.55)) {
                dominant = rgb
            }
        } catch {
            // 封面加载失败：保持主题色回退，不影响播放
        }
    }

    private func fetchCover(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = URLCache.shared.cachedResponse(for: request)?.data {
            return cached
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

// MARK: - 自定义进度条（点击 / 拖动均可跳转，配色跟随封面主色）

struct SeekBar: View {
    @EnvironmentObject private var player: PlayerManager
    let accent: Color
    let track: Color

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
                    .fill(track)
                    .frame(height: 5)
                Capsule()
                    .fill(accent)
                    .frame(width: thumbX, height: 5)
                Circle()
                    .fill(accent)
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

// MARK: - 系统音量条（MPVolumeView 封装，颜色跟随封面主色）

struct SystemVolumeSlider: UIViewRepresentable {
    var tint: Color

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        DispatchQueue.main.async {
            for sub in uiView.subviews {
                if let slider = sub as? UISlider {
                    slider.minimumTrackTintColor = UIColor(tint)
                    slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
                    slider.thumbTintColor = UIColor.white
                }
            }
        }
    }
}

// MARK: - 歌词（居中显示 + 逐行高亮 + 自动滚动 + 点击跳转；切歌强制重建视图刷新布局）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let lyrics: [LyricLine]
    let accent: Color
    let secondary: Color
    let onTapLine: (LyricLine) -> Void

    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        return lyrics.lastIndex { $0.time <= player.progress }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: index == currentIndex ? 18 : 14.5,
                                          weight: index == currentIndex ? .bold : .regular))
                            .foregroundStyle(index == currentIndex ? accent : secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 36)
                            .scaleEffect(index == currentIndex ? 1.04 : 1)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapLine(line) }
                            .id(index)
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
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