import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var topLists: [TopList] = []
    @State private var dailySongs: [Song] = []
    @State private var personalized: [Playlist] = []

    @State private var loading = true
    @State private var errorMessage: String?
    @State private var selectedTopList: TopList?
    @State private var selectedPlaylist: Playlist?
    @State private var showDailyList = false
    /// 首页数据源：网易云 / QQ音乐（与搜索页同一控件样式）
    @State private var source: SearchProvider = .netease
    @State private var qqTopLists: [QQTopInfo] = []
    @State private var selectedQQTopList: QQTopInfo?
    @State private var selectedQQPlaylist: Playlist?

    var body: some View {
        let _ = theme.accent
        ZStack {
            // 仅主页模式：自定义背景只应用在发现页（图片优先，其次颜色）
            if !theme.backgroundSyncAll, let image = theme.customBackgroundImage {
                WallpaperImage(image: image)
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [.black.opacity(0.35), .black.opacity(0.55)]
                        : [.black.opacity(0.08), .black.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            } else if !theme.backgroundSyncAll, let custom = theme.customBackground {
                LinearGradient(
                    colors: [custom.opacity(0.85), custom.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else if loading {
                    LoadingStateView()
                } else {
                    if !dailySongs.isEmpty {
                        dailySection
                    }
                    if !topLists.isEmpty {
                        topListsSection
                    }
                    if !personalized.isEmpty {
                        personalizedSection
                    }

                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }

        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .task(id: source) { await load() }
        .sheet(item: $selectedTopList) { topList in
            TopListDetailView(topList: topList)
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(item: $selectedQQTopList) { info in
            QQTopListDetailView(topID: info.id, name: info.name)
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(item: $selectedQQPlaylist) { playlist in
            QQPlaylistSongsSheet(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
        }
            .sheet(isPresented: $showDailyList) {
                DailySongsSheet(songs: dailySongs)
                    .environmentObject(player)
                    .environmentObject(auth)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text(auth.user?.nickname ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer()
                GlassIconButton(systemName: "arrow.clockwise") {
                    Task { await load() }
                }
            }
            providerPicker
        }
        .padding(.top, 8)
    }

    /// 平台选择（网易云 / QQ音乐，样式与搜索页一致）
    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(SearchProvider.allCases) { p in
                Button {
                    BeansHaptics.tap()
                    if source != p { source = p }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: p.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(p.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(source == p ? Color.white : Color.beansSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if source == p {
                            Capsule().fill(p.tint)
                        } else {
                            Capsule().fill(.clear)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
        }
        .clipShape(Capsule())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var topListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "排行榜")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                spacing: 12
            ) {
                // 纯封面液态玻璃卡片（无文字）：网易云榜单 / QQ 峰尖榜
                if source == .netease {
                    ForEach(topLists.prefix(6)) { topList in
                        Button {
                            selectedTopList = topList
                        } label: {
                            CoverImage(url: topList.coverURL, size: 88, cornerRadius: 14)
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background {
                                    GlassEffectContainer {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(.clear)
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(qqTopLists.prefix(6)) { info in
                        Button {
                            selectedQQTopList = info
                        } label: {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(qqRankGradient(info.name))
                                .frame(width: 88, height: 88)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background {
                                    GlassEffectContainer {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(.clear)
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// QQ 峰尖榜占位封面：按榜单名确定性取一组渐变，不加载网络图
    private func qqRankGradient(_ name: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.20, green: 0.30, blue: 0.65)],
            [Color(red: 0.95, green: 0.42, blue: 0.36), Color(red: 0.70, green: 0.18, blue: 0.20)],
            [Color(red: 0.20, green: 0.78, blue: 0.62), Color(red: 0.08, green: 0.52, blue: 0.44)],
            [Color(red: 0.92, green: 0.62, blue: 0.25), Color(red: 0.72, green: 0.38, blue: 0.12)],
            [Color(red: 0.62, green: 0.45, blue: 0.90), Color(red: 0.40, green: 0.25, blue: 0.68)],
            [Color(red: 0.30, green: 0.70, blue: 0.85), Color(red: 0.16, green: 0.45, blue: 0.65)]
        ]
        let seed = abs(name.hashValue) % palettes.count
        return LinearGradient(colors: palettes[seed], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "每日推荐", trailing: "查看全部") {
                BeansHaptics.tap()
                showDailyList = true
            }
            // 每日推荐大卡片：点击查看今日全部推荐
            Button {
                BeansHaptics.tap()
                showDailyList = true
            } label: {
                HStack(spacing: 14) {
                    CoverImage(url: dailySongs.first?.coverURL, size: 58, cornerRadius: 13)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("为你精选 \(dailySongs.count) 首")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Text("每日更新 · 按你的口味推荐")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansSecondary)
                }
                .padding(14)
                .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.97))

            // 播放全部 / 随机播放：与封面左边缘对齐
            HStack(spacing: 10) {
                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                    BeansHaptics.tap()
                    player.play(songs: dailySongs, startAt: 0)
                }
                GlassButton(title: "随机播放", systemName: "shuffle") {
                    BeansHaptics.tap()
                    player.play(songs: dailySongs, startAt: Int.random(in: 0..<dailySongs.count))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .beansCardShadow(radius: 8, y: 3)

            VStack(spacing: 0) {
                ForEach(Array(dailySongs.prefix(3).enumerated()), id: \.element.id) { index, song in
                    SongCell(song: song) {
                        BeansHaptics.tap()
                        player.play(songs: dailySongs, startAt: index)
                    }
                    Divider().overlay(Color.beansSecondary.opacity(0.15))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .beansCardShadow(radius: 8, y: 3)
        }
    }
    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "歌单广场")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                spacing: 12
            ) {
                // 精简：三列小卡片只显示前六个，不再又长又大
                ForEach(personalized.prefix(6)) { playlist in
                    Button {
                        if source == .qq {
                            selectedQQPlaylist = playlist
                        } else {
                            selectedPlaylist = playlist
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            CoverImage(url: playlist.coverURL, size: 88, cornerRadius: 14)
                                .frame(maxWidth: .infinity)
                            Text(playlist.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GlassEffectContainer {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.clear)
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }



    // MARK: - 动作

    private func load() async {
        loading = true
        errorMessage = nil
        if source == .qq {
            do {
                async let a = QQMusicAPI.shared.recommendSongs(limit: 30)
                async let b = QQMusicAPI.shared.topLists()
                async let c = QQMusicAPI.shared.recommendPlaylists(limit: 12)
                let (dr, tl, pp) = try await (a, b, c)
                dailySongs = dr
                qqTopLists = tl
                personalized = pp
                loading = false
            } catch {
                errorMessage = error.localizedDescription
                loading = false
            }
        } else {
            async let a = NetEaseAPI.shared.topLists()
            async let b = NetEaseAPI.shared.dailyRecommend()
            async let c = NetEaseAPI.shared.playlistSquare(limit: 10)
            do {
                let (tl, dr, pp) = try await (a, b, c)
                topLists = tl
                dailySongs = dr
                personalized = pp
                loading = false
            } catch {
                errorMessage = error.localizedDescription
                loading = false
            }
        }
    }
}

// MARK: - QQ 峰尖榜详情

struct QQTopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    let topID: Int
    let name: String
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        Section {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song) {
                                    player.play(songs: tracks, startAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await QQMusicAPI.shared.topListSongs(topid: topID)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - QQ 歌单内歌曲

struct QQPlaylistSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    let playlist: Playlist
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        Section {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song) {
                                    player.play(songs: tracks, startAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await QQMusicAPI.shared.playlistSongs(listID: playlist.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - 每日推荐全部歌曲

struct DailySongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore

    let songs: [Song]

    var body: some View {
        let _ = theme.accent
        NavigationStack {
            Group {
                if songs.isEmpty {
                    EmptyStateView(icon: "sparkles", text: "今日推荐加载中，下拉刷新试试")
                } else {
                    List {
                    Section {
                        HStack(spacing: 12) {
                            GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                BeansHaptics.tap()
                                player.play(songs: songs, startAt: 0)
                            }
                            GlassButton(title: "随机播放", systemName: "shuffle") {
                                BeansHaptics.tap()
                                player.play(songs: songs, startAt: Int.random(in: 0..<songs.count))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                    }
                    Section {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song) {
                                BeansHaptics.tap()
                                player.play(songs: songs, startAt: index)
                            }
                        }
                    }
                }
                }
            }
            .navigationTitle("今日推荐")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
// MARK: - 排行榜详情

struct TopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore

    let topList: TopList
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        header
                        Section {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song) {
                                    player.play(songs: tracks, startAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(topList.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CoverImage(url: topList.coverURL, size: 88, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 6) {
                Text(topList.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                Text(topList.updateFrequency)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansSecondary)
                Text("\(tracks.count) 首")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await NetEaseAPI.shared.playlistTracks(id: topList.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}
