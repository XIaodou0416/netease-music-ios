import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

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
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                if showLyrics {
                    lyricsPane
                } else {
                    Spacer(minLength: 2)
                    coverButton
                    songInfo
                        .padding(.horizontal, 26)
                        .padding(.top, 16)
                }
                Spacer(minLength: 8)
                SeekBar()
                    .padding(.horizontal, 26)
                timeRow
                    .padding(.horizontal, 26)
                    .padding(.top, 8)
                controlsRow
                    .padding(.top, 12)
                bottomRow
                    .padding(.top, 14)
                    .padding(.bottom, 26)
            }
            .offset(y: dragOffset)
            .opacity(1 - min(dragOffset / 480, 0.6))
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
        .sheet(isPresented: $showComments) {
            if let song {
                CommentsSheet(song: song)
            }
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.beansBackground,
                    Color(uiColor: .beansBackground).opacity(0.9),
                ],
                startPoint: .top, endPoint: .bottom
            )
            AsyncImage(url: song?.coverURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 40)
                        .opacity(0.35)
                }
            }
            .ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.25), .clear, .black.opacity(0.4)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
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

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Spacer()

            VStack(spacing: 2) {
                Text(player.isBuffering ? "加载中…" : (player.isPlaying ? "正在播放" : "已暂停"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(song?.album ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)

            Spacer()

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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    // MARK: - 封面（点击切换歌词）

    private var coverButton: some View {
        Button {
            toggleLyrics()
        } label: {
            CoverImage(url: song?.coverURL, size: 244, cornerRadius: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 26, y: 12)
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
    }

    private var songInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(song?.name ?? "")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(song?.artists ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if auth.isLoggedIn, let song {
                Button {
                    BeansHaptics.tap()
                    Task { _ = try? await auth.toggleLike(song) }
                } label: {
                    Image(systemName: isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(isLiked(song) ? Color.beansAmber : Color.beansLabel)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle().fill(.ultraThinMaterial)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
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

    // MARK: - 时间行

    private var timeRow: some View {
        HStack(spacing: 8) {
            seekPillButton("gobackward.15") { player.seekBy(-15) }
            Spacer()
            Text(beansTimeString(player.progress))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.beansSecondary)
            Spacer()
            Text(beansTimeString(player.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.beansSecondary)
            Spacer()
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

    // MARK: - 主控制

    private var controlsRow: some View {
        HStack(spacing: 28) {
            Button {
                player.togglePlayMode()
                BeansHaptics.select()
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Button {
                BeansHaptics.tap()
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 56, height: 56)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Button {
                BeansHaptics.tap()
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(width: 78, height: 78)
                    .background {
                        Circle()
                            .fill(LinearGradient.beansAccent)
                            .overlay {
                                Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .clipShape(Circle())
                    .shadow(color: Color.beansAmber.opacity(0.45), radius: 18, y: 8)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.92))

            Button {
                BeansHaptics.tap()
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 56, height: 56)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Button {
                showQueue = true
            } label: {
                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.beansSecondary)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
        }
    }

    // MARK: - 底部功能行

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
                    .foregroundStyle(showLyrics ? Color.beansAmber : Color.beansSecondary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle().fill(.ultraThinMaterial)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())

            Menu {
                Button {
                    showSleepTimer = true
                } label: {
                    if player.sleepTimerRemaining > 0 {
                        Label("睡眠定时 \(player.sleepTimerFormatted ?? "")", systemImage: "moon.zzz.fill")
                    } else {
                        Label("睡眠定时", systemImage: "moon.zzz")
                    }
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

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.beansSecondary.opacity(0.25))
                    .frame(height: 5)
                Capsule()
                    .fill(LinearGradient.beansAccent)
                    .frame(width: max(width * ratio, 6), height: 5)
                Circle()
                    .fill(Color.beansAmber)
                    .frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: max(width * ratio - 7.5, -7.5))
            }
            .frame(width: width, height: 28)
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
        .frame(height: 28)
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
                            .foregroundStyle(index == currentIndex ? Color.beansAmber : Color.beansSecondary)
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