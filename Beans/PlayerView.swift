import SwiftUI
import UIKit
import MediaPlayer

// MARK: - 全屏播放器（全新重写：极简稳定布局）
// 布局原则：
// - 全部使用 SwiftUI 自动布局（VStack/HStack/ZStack），不使用 position / matchedGeometryEffect / 绝对定位。
// - 专辑模式与歌词模式是两个独立视图，if/else + transition 切换，各自内部自然居中，任何屏幕与加载时序下都稳定。
// - 封面使用固定尺寸 CoverImage（AsyncImage 仅在 overlay 中渲染），封面加载、切歌都不会影响布局。
// - 底部控制栏为普通材质圆角面板，按钮等宽对称分布，无液态玻璃依赖。
// 音频播放 / 网络 / 登录业务逻辑保持不变。

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

    /// 固定调色板：跟随全局主题与深浅模式。
    /// 封面取色必须禁用：任何封面加载触发的 @State 更新都会引起整页重绘，导致“封面加载后布局错乱”。
    private var palette: CoverPalette {
        CoverPalette.fallback(colorScheme: colorScheme)
    }

    var body: some View {
        let _ = theme.accent
        GeometryReader { geo in
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    content(geo: geo)
                }
                .foregroundStyle(palette.text)

                VStack(spacing: 0) {
                    controlDeck
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .task(id: song?.identityKey) {
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

    // MARK: - 背景（主题渐变兜底 + 封面毛玻璃 + 可读性遮罩）
    // 毛玻璃封面为 UIKit 独立图层（CoverBlurBackground），加载/换图不经过 SwiftUI
    // 布局，因此封面加载完成不会引发布局重算，彻底避免"封面加载后错乱"。

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            CoverBlurBackground(url: song?.coverURL, scheme: colorScheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.black.opacity(0.22), .clear, .black.opacity(0.34)]
                    : [.white.opacity(0.08), .clear, .black.opacity(0.12)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
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

    // MARK: - 中间内容区（专辑 / 歌词 两模式独立视图，自动布局居中）

    @ViewBuilder
    private func content(geo: GeometryProxy) -> some View {
        ZStack {
            if song == nil {
                placeholderView
            } else if showLyrics {
                lyricsPanel
                    .transition(.opacity)
            } else {
                albumPanel(geo: geo)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.22), value: showLyrics)
    }

    /// 封面尺寸：固定算法，与布局时序无关
    private func coverSize(in geo: GeometryProxy) -> CGFloat {
        min(280, min(geo.size.width * 0.60, geo.size.height * 0.44))
    }

    /// 专辑模式：封面居中 + 歌名/歌手 + 轻点提示（VStack 自动居中）
    private func albumPanel(geo: GeometryProxy) -> some View {
        let size = coverSize(in: geo)
        return VStack(spacing: 16) {
            Spacer(minLength: 2)

            Button {
                toggleLyrics()
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.18))
                        .frame(width: size * 1.20, height: size * 1.20)
                        .blur(radius: 38)
                    CoverImage(url: song?.coverURL, size: size, cornerRadius: min(24, size * 0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: min(24, size * 0.08), style: .continuous)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.96))

            VStack(spacing: 6) {
                Text(song?.name ?? "未在播放")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 36)

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 歌词模式：左上小封面 + 歌名信息条 + 居中歌词（自动布局）
    private var lyricsPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    toggleLyrics()
                } label: {
                    CoverImage(url: song?.coverURL, size: 48, cornerRadius: 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song?.name ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(song?.artists ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Button {
                    toggleLyrics()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 36, height: 36)
                        .background { Circle().fill(.ultraThinMaterial) }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

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
        .id("lyricsPanel-\(song?.identityKey ?? "none")")
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

    // MARK: - 底部控制栏（普通材质圆角面板：进度 / 主控制 / 工具行）

    private var controlDeck: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(palette.secondary.opacity(0.4))
                .frame(width: 34, height: 4)
                .padding(.top, 6)

            progressBlock
            mainControls
            utilityRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            // iOS 原生液态玻璃面板，延伸到底部安全区贴满屏幕底部，不留空白
            GlassEffectContainer {
                UnevenRoundedRectangle(
                    topLeadingRadius: 30, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 30,
                    style: .continuous
                )
                .fill(.clear)
                .glassEffect(.clear, in: UnevenRoundedRectangle(
                    topLeadingRadius: 30, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 30,
                    style: .continuous
                ))
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 1)
            }
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 30, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 30,
            style: .continuous
        ))
        .shadow(color: .black.opacity(0.18), radius: 20, y: -5)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    // MARK: - 主控制（5 键等宽对称，播放键居中）

    private var mainControls: some View {
        HStack(spacing: 6) {
            deckButton(icon: player.playMode.icon) {
                BeansHaptics.select()
                player.togglePlayMode()
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

    // MARK: - 工具行（倍速 / 音量条 / 歌词开关 / 更多菜单）

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

            Spacer(minLength: 4)

            SystemVolumeSlider(tint: palette.accent)
                .frame(width: 110, height: 24)

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
        withAnimation(.easeInOut(duration: 0.22)) {
            showLyrics.toggle()
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

// MARK: - 歌词（居中显示 + 逐行高亮 + 自动滚动 + 点击跳转）

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
