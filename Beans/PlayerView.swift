import SwiftUI
import UIKit

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
    @State private var showDownloadPicker = false
    @State private var showLyricSettings = false
    @State private var showArtistHome = false
    @State private var dominantColor: RGBColor?
    @AppStorage("beans.lyricFontSize") private var lyricFontSize = 17
    @AppStorage("beans.lyricColor") private var lyricColorRaw = "accent"
    @AppStorage("beans.lyricDimColor") private var lyricDimColorRaw = "dim"
    @AppStorage("beans.lyricGlow") private var lyricGlowLevel = 1
    @AppStorage("beans.lyricGradStart") private var lyricGradStartRaw = ""
    @AppStorage("beans.lyricGradEnd") private var lyricGradEndRaw = ""

    private var song: Song? { player.currentSong }
    private let rateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// 封面主色联动调色板：背景渐变 / 进度条 / 播放暂停键 / 功能按钮 / 歌词高亮等全部跟随封面主色。
    /// 安全机制：只在切歌（.task(id: song?.identityKey)）时一次性提取并更新，绝不随封面加载过程高频重算 @State，
    /// 避免整页反复重绘导致的布局错乱与发烫。深浅模式切换时及时重算配色。
    private var palette: CoverPalette {
        if let dominantColor {
            return CoverPalette.make(dominant: dominantColor, colorScheme: colorScheme)
        }
        return CoverPalette.fallback(colorScheme: colorScheme)
    }

    /// 当前行歌词颜色（可自定义，默认跟随主题）
    private var lyricCurrentColor: Color {
        switch lyricColorRaw {
        case "white": return .white
        case "amber": return Color.beansAmber
        case "cyan": return Color(red: 0.35, green: 0.85, blue: 0.96)
        case "pink": return Color(red: 1.0, green: 0.62, blue: 0.82)
        case "green": return Color(red: 0.42, green: 0.90, blue: 0.62)
        default:
            if lyricColorRaw.hasPrefix("#"), let c = Color(hex: lyricColorRaw) { return c }
            return palette.accent
        }
    }

    /// 未播放歌词颜色（可自定义，默认淡灰）
    private var lyricDimColor: Color {
        switch lyricDimColorRaw {
        case "white": return .white.opacity(0.78)
        case "bluegray": return Color(red: 0.72, green: 0.78, blue: 0.86)
        case "gray": return Color.gray.opacity(0.85)
        case "dark": return Color.black.opacity(0.55)
        default:
            if lyricDimColorRaw.hasPrefix("#"), let c = Color(hex: lyricDimColorRaw) { return c }
            return palette.secondary
        }
    }

    /// 当前行歌词渐变（可自定义起止色；未设置时自动从封面强调色派生，深浅模式自适应）
    private var lyricGradStart: Color {
        if lyricGradStartRaw.hasPrefix("#"), let c = Color(hex: lyricGradStartRaw) { return c }
        return lyricCurrentColor
    }
    private var lyricGradEnd: Color {
        if lyricGradEndRaw.hasPrefix("#"), let c = Color(hex: lyricGradEndRaw) { return c }
        return mixedColor(lyricCurrentColor, with: colorScheme == .dark ? .white : .black, amount: 0.45)
    }
    private func mixedColor(_ c: Color, with other: Color, amount: CGFloat) -> Color {
        let ui = UIColor(c)
        let ui2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let a = min(max(amount, 0), 1)
        return Color(red: r1 * (1 - a) + r2 * a, green: g1 * (1 - a) + g2 * a, blue: b1 * (1 - a) + b2 * a)
    }

    private func glowName(_ level: Int) -> String {
        switch level {
        case 0: return "关闭"
        case 1: return "柔和"
        case 2: return "标准"
        default: return "强烈"
        }
    }

    /// 发光强度对应的 shadow 半径（0 关闭，最大 32，叠双层光晕更亮）
    private var lyricGlowRadius: CGFloat {
        switch lyricGlowLevel {
        case 0: return 0
        case 1: return 6
        case 2: return 12
        case 3: return 18
        case 4: return 25
        default: return 32
        }
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

                controlDeck
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .task(id: song?.identityKey) {
            dominantColor = nil
            await loadLyrics()
            await extractCoverPalette()
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
        .sheet(isPresented: $showLyricSettings) {
            LyricSettingsSheet(
                fontSize: $lyricFontSize,
                glowLevel: $lyricGlowLevel,
                currentColorRaw: $lyricColorRaw,
                dimColorRaw: $lyricDimColorRaw,
                gradStartRaw: $lyricGradStartRaw,
                gradEndRaw: $lyricGradEndRaw,
                palette: palette
            )
        }
        .sheet(isPresented: $showArtistHome) {
            if !primaryArtistName.isEmpty {
                ArtistHomeSheet(artistName: primaryArtistName)
                    .environmentObject(player)
            }
        }
        .confirmationDialog("下载《\(song?.name ?? "当前歌曲")》", isPresented: $showDownloadPicker, titleVisibility: .visible) {
            ForEach(DownloadQuality.allCases) { quality in
                Button(quality.label) {
                    Task { await downloadCurrent(quality) }
                }
            }
            Button("取消", role: .cancel) {}
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
                    .background {
                        GlassEffectContainer {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.clear, in: Circle())
                        }
                    }
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

            Menu {
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
                    Label("倍速播放", systemImage: "speedometer")
                }
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
                Button {
                    showDownloadPicker = true
                } label: {
                    Label("下载歌曲", systemImage: "arrow.down.circle")
                }
                Divider()
                Button {
                    showLyricSettings = true
                } label: {
                    Label("歌词设置", systemImage: "textformat.size")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 38, height: 38)
                    .background {
                        GlassEffectContainer {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.clear, in: Circle())
                        }
                    }
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
                    .contentShape(Rectangle())
                    .onTapGesture { openArtistHome() }
            }
            .padding(.horizontal, 36)

            Spacer(minLength: 2)
        }
        .padding(.bottom, deckInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 歌词模式：左上小封面 + 歌名信息条 + 居中歌词（自动布局，歌词可滚动到底部透过底栏玻璃）
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
                        .contentShape(Rectangle())
                        .onTapGesture { openArtistHome() }
                }

                Spacer(minLength: 0)

                Button {
                    toggleLyrics()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 36, height: 36)
                        .background {
                            GlassEffectContainer {
                                Circle()
                                    .fill(.clear)
                                    .glassEffect(.clear, in: Circle())
                            }
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // 歌词视口截止到底栏上方：当前行在可见区居中（26 版风格，无渐隐遮挡）
            Group {
                if lyrics.isEmpty {
                    emptyLyricsView
                } else {
                    LyricsSection(lyrics: lyrics, accent: lyricCurrentColor, secondary: lyricDimColor, gradientStart: lyricGradStart, gradientEnd: lyricGradEnd, baseFontSize: CGFloat(lyricFontSize), glowRadius: lyricGlowRadius) { line in
                        BeansHaptics.tap()
                        player.seek(to: line.time)
                    }
                }
            }
            .padding(.bottom, deckInset)
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
                    .background {
                        GlassEffectContainer {
                            Capsule()
                                .fill(.clear)
                                .glassEffect(.clear, in: Capsule())
                        }
                    }
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

    /// 底部控制栏估算高度（单行控制后降低，给歌词视口更多空间）
    private let deckInset: CGFloat = 130

    private var controlDeck: some View {
        VStack(spacing: 8) {
            deckRow
            progressBlock
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        // 底部控件直接悬浮在模糊背景上：单行控制 + 底部进度条，歌词视口更大
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

    // MARK: - 合并控制行（循环 / 上一曲 / 播放暂停 / 下一曲 / 播放列表 平行排列，播放键居中）

    private var deckRow: some View {
        HStack(spacing: 8) {
            modeButton
                .frame(maxWidth: .infinity)
            deckButton(icon: "backward.fill", expand: false) {
                BeansHaptics.tap()
                player.previous()
            }
            .frame(maxWidth: .infinity)
            playButton
                .frame(maxWidth: .infinity)
            deckButton(icon: "forward.fill", expand: false) {
                BeansHaptics.tap()
                player.next()
            }
            .frame(maxWidth: .infinity)
            queueButton
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .simultaneousGesture(
            // 上滑控制行呼出评论区（进度条区域保留拖动，不误触）
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    if value.translation.height < -50, song != nil {
                        BeansHaptics.medium()
                        showComments = true
                    }
                }
        )
    }

    /// 循环 / 随机播放按钮（随机模式高亮）
    private var modeButton: some View {
        Button {
            BeansHaptics.select()
            player.togglePlayMode()
        } label: {
            Image(systemName: player.playMode.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(player.playMode == .shuffle ? palette.accent : palette.secondary)
                .frame(width: 30, height: 30)
                .background {
                    GlassEffectContainer {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.clear, in: Circle())
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    /// 播放列表按钮
    private var queueButton: some View {
        Button {
            BeansHaptics.tap()
            showQueue = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .frame(width: 30, height: 30)
                .background {
                    GlassEffectContainer {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.clear, in: Circle())
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }

    private func deckButton(icon: String, accent: Bool = false, expand: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent ? palette.accent : palette.text)
                .frame(width: 40, height: 40)
                .background {
                    GlassEffectContainer {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.clear, in: Circle())
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
        .frame(maxWidth: expand ? .infinity : nil)
    }

    private var playButton: some View {
        Button {
            BeansHaptics.tap()
            player.togglePlayPause()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(player.isPlaying ? 1.0 : 0.88)
                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: player.isPlaying)
                .frame(width: 52, height: 52)
                .background {
                    GlassEffectContainer {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.clear, in: Circle())
                    }
                    .overlay {
                        Circle().fill(
                            LinearGradient(
                                colors: [palette.accent.opacity(0.55), palette.accentSoft.opacity(0.55)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.30), lineWidth: 1)
                    }
                }
                .clipShape(Circle())
                .shadow(color: palette.accent.opacity(0.4), radius: 14, y: 7)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        .frame(maxWidth: .infinity)
    }


    // MARK: - 下载

    private func downloadCurrent(_ quality: DownloadQuality) async {
        guard let song else { return }
        BeansHaptics.medium()
        ToastCenter.shared.show("开始下载：\(song.name)")
        let result = await DownloadManager.shared.download(song: song, quality: quality)
        switch result {
        case .success(let downloadResult):
            let message = downloadResult.downgraded
                ? "已下载（所选音质不可用，已自动降级）：\(song.name)"
                : "已下载：\(song.name)（可在文件 App 查看）"
            ToastCenter.shared.show(message, duration: 3)
        case .failure(let error):
            ToastCenter.shared.show("下载失败：\(error.localizedDescription)", duration: 3)
        }
    }

    // MARK: - 动作

    /// 首位歌手名（用于跳转歌手主页）
    private var primaryArtistName: String {
        guard let artists = song?.artists else { return "" }
        return artists
            .replacingOccurrences(of: " / ", with: "/")
            .split(separator: "/")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .description ?? ""
    }

    private func openArtistHome() {
        guard !primaryArtistName.isEmpty else { return }
        BeansHaptics.tap()
        showArtistHome = true
    }

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

    /// 一次性提取当前封面主色，带动整个播放器配色动态变化（失败时保持主题回退色，不影响任何功能）
    private func extractCoverPalette() async {
        guard let url = song?.coverURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data),
                  let dominant = PaletteExtractor.dominantColor(in: image) else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                dominantColor = dominant
            }
        } catch {
            // 提取失败：静默保持回退色
        }
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
                // 底轨：iOS 原生清透材质（超薄材质采样背景）
                Capsule()
                    .fill(track)
                    .frame(height: 5)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: 5)
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    }
                // 已播放段：强调色渐变 + 顶部高光
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.72)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: thumbX, height: 5)
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 2.5)
                        .clipShape(Capsule())
                        .padding(.horizontal, 2)
                    }
                // 滑块：原生小圆点（白色 + 细描边）
                Circle()
                    .fill(.white)
                    .frame(width: scrubbing ? 20 : 14, height: scrubbing ? 20 : 14)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.95), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.22), radius: scrubbing ? 5 : 2.5, y: scrubbing ? 2 : 1)
                    .offset(x: thumbX - (scrubbing ? 10 : 7))
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: scrubbing)
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

// MARK: - 歌词（居中显示 + 逐行高亮 + 自动滚动 + 点击跳转）

struct LyricsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let lyrics: [LyricLine]
    let accent: Color
    let secondary: Color
    var gradientStart: Color? = nil
    var gradientEnd: Color? = nil
    var baseFontSize: CGFloat = 17
    var glowRadius: CGFloat = 9
    let onTapLine: (LyricLine) -> Void

    /// 二分查找当前行（歌词按时间升序），避免逐行扫描降低 CPU
    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= player.progress {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        lyricRow(index: index, line: line)
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

    /// Apple Music 风格渐隐：当前行最大最亮，已播放行与未播放行按距离逐层变暗变淡
    private func lyricRow(index: Int, line: LyricLine) -> some View {
        let isCurrent = index == currentIndex
        let isPlayed = (currentIndex ?? -1) >= 0 && index < (currentIndex ?? 0)
        let distance = abs(index - (currentIndex ?? 0))
        let opacity: Double = isCurrent
            ? 1.0
            : (isPlayed ? 0.38 : 0.72) - Double(min(distance, 4)) * 0.05
        let size = isCurrent ? baseFontSize + 4 : baseFontSize - CGFloat(min(distance, 2)) * 1.5
        // 歌词行模糊：当前行与邻近行保持清晰，距离越远才越柔和（避免只剩一行清晰显得突兀）
        let blurRadius: CGFloat = isCurrent ? 0 : min(CGFloat(max(distance - 1, 0)) * 1.1, 2.8)

        // 当前行用渐变（封面色或自定义），光晕跟随渐变起始色
        let lineStyle: AnyShapeStyle
        if isCurrent, let gradientStart, let gradientEnd {
            lineStyle = AnyShapeStyle(LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .top, endPoint: .bottom))
        } else {
            lineStyle = AnyShapeStyle(isCurrent ? accent : secondary)
        }
        let glowColor = isCurrent ? (gradientStart ?? accent) : accent

        return Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(
                size: size,
                weight: isCurrent ? .bold : .regular,
                design: .rounded
            ))
            .foregroundStyle(lineStyle)
            // 双层光晕：内层亮、外层宽，发光更明显
            .shadow(
                color: isCurrent ? glowColor.opacity(glowRadius > 0 ? 0.9 : 0) : .clear,
                radius: isCurrent ? glowRadius * 0.45 : 0
            )
            .shadow(
                color: isCurrent ? glowColor.opacity(glowRadius > 0 ? 0.55 : 0) : .clear,
                radius: isCurrent ? glowRadius : 0
            )
            .blur(radius: blurRadius)
            .opacity(max(opacity, 0.15))
            .scaleEffect(isCurrent ? 1.05 : 1)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 36)
            .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let currentIndex else { return }
        proxy.scrollTo(currentIndex, anchor: .center)
    }
}

// MARK: - 歌词设置面板（更多菜单 → 歌词设置：字号 / 发光强度 / 颜色色盘）

struct LyricSettingsSheet: View {
    @Binding var fontSize: Int
    @Binding var glowLevel: Int
    @Binding var currentColorRaw: String
    @Binding var dimColorRaw: String
    @Binding var gradStartRaw: String
    @Binding var gradEndRaw: String
    let palette: CoverPalette
    @Environment(\.dismiss) private var dismiss

    /// 当前行高亮色：任意色盘选色写入 hex，关闭面板后依然生效
    private var currentColor: Binding<Color> {
        Binding(
            get: {
                if currentColorRaw.hasPrefix("#"), let c = Color(hex: currentColorRaw) { return c }
                return palette.accent
            },
            set: { newValue in
                currentColorRaw = "#" + UIColor(newValue).hexString
            }
        )
    }

    /// 未播放歌词颜色：同上，任意色盘选色
    private var dimColor: Binding<Color> {
        Binding(
            get: {
                if dimColorRaw.hasPrefix("#"), let c = Color(hex: dimColorRaw) { return c }
                return palette.secondary
            },
            set: { newValue in
                dimColorRaw = "#" + UIColor(newValue).hexString
            }
        )
    }

    /// 渐变起始色：任意色盘选色，空值时自动用封面强调色
    private var gradStart: Binding<Color> {
        Binding(
            get: {
                if gradStartRaw.hasPrefix("#"), let c = Color(hex: gradStartRaw) { return c }
                return palette.accent
            },
            set: { newValue in
                gradStartRaw = "#" + UIColor(newValue).hexString
            }
        )
    }

    /// 渐变结束色：任意色盘选色，空值时自动用封面色派生色
    private var gradEnd: Binding<Color> {
        Binding(
            get: {
                if gradEndRaw.hasPrefix("#"), let c = Color(hex: gradEndRaw) { return c }
                return palette.accent
            },
            set: { newValue in
                gradEndRaw = "#" + UIColor(newValue).hexString
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    HStack(spacing: 12) {
                        Text("A")
                            .font(.system(size: 13, weight: .semibold))
                        Slider(
                            value: Binding(
                                get: { Double(fontSize) },
                                set: { fontSize = Int($0) }
                            ),
                            in: 12...28,
                            step: 1
                        )
                        .tint(Color.beansAmber)
                        Text("A")
                            .font(.system(size: 22, weight: .bold))
                    }
                    Text("\(fontSize) pt")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }

                Section("发光强度") {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.beansAmber)
                        Slider(
                            value: Binding(
                                get: { Double(glowLevel) },
                                set: { glowLevel = Int($0) }
                            ),
                            in: 0...5,
                            step: 1
                        )
                        .tint(Color.beansAmber)
                        Image(systemName: glowLevel > 2 ? "sparkles" : "sparkle")
                            .foregroundStyle(glowLevel > 2 ? Color.beansAmber : Color.beansSecondary)
                    }
                    Text(glowName(glowLevel))
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }

                Section("歌词颜色") {
                    ColorPicker("当前行颜色", selection: currentColor, supportsOpacity: false)
                    ColorPicker("未播放行颜色", selection: dimColor, supportsOpacity: false)
                }

                Section("歌词渐变") {
                    ColorPicker("渐变起始色", selection: gradStart, supportsOpacity: false)
                    ColorPicker("渐变结束色", selection: gradEnd, supportsOpacity: false)
                    Button("恢复默认渐变") {
                        gradStartRaw = ""
                        gradEndRaw = ""
                        BeansHaptics.select()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansAmber)
                }
            }
            .navigationTitle("歌词设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func glowName(_ level: Int) -> String {
        switch level {
        case 0: return "关闭"
        case 1: return "柔和"
        case 2: return "标准"
        case 3: return "强烈"
        case 4: return "明亮"
        default: return "极亮"
        }
    }
}
