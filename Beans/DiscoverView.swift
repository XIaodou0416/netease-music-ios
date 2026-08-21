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
                VStack(alignment: .leading, spacing: 26) {
                    header
                    providerPicker
                    if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load() }
                        }
                    } else if loading {
                        LoadingStateView()
                    } else {
                        if !dailySongs.isEmpty {
                            dailySection.sectionEntrance(delay: 0)
                        }
                        if !topLists.isEmpty {
                            topListsSection.sectionEntrance(delay: 0.08)
                        }
                        if !personalized.isEmpty {
                            personalizedSection.sectionEntrance(delay: 0.16)
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

    /// 顶部问候区：大标题 + 刷新按钮
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(BeansFont.appFont(30, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text(auth.user?.nickname ?? "发现好音乐")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer()
                GlassIconButton(systemName: "arrow.clockwise") {
                    BeansHaptics.tap()
                    Task { await load() }
                }
            }
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
                            .font(BeansFont.appFont(13, .semibold))
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

    /// 排行榜：横向滑动液态玻璃卡片（网易云榜单 / QQ 峰尖榜）
    private var topListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "排行榜")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if source == .netease {
                        ForEach(topLists) { topList in
                            topListCard(topList: topList)
                        }
                    } else {
                        ForEach(qqTopLists) { info in
                            qqTopCard(info: info)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func topListCard(topList: TopList) -> some View {
        Button {
            BeansHaptics.tap()
            selectedTopList = topList
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CoverImage(url: topList.coverURL, size: 140, cornerRadius: 18)
                    .overlay(alignment: .bottomLeading) {
                        Text(topList.updateFrequency)
                            .font(BeansFont.appFont(10, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.42), in: Capsule())
                            .padding(8)
                    }
                Text(topList.name)
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(8)
            .background {
                GlassEffectContainer {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .beansCardShadow(radius: 10, y: 4)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
    }

    private func qqTopCard(info: QQTopInfo) -> some View {
        Button {
            BeansHaptics.tap()
            selectedQQTopList = info
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let cover = info.coverURL {
                        CoverImage(url: cover, size: 140, cornerRadius: 18)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(qqRankGradient(info.name))
                            .frame(width: 140, height: 140)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                    }
                }
                Text(info.name)
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(8)
            .background {
                GlassEffectContainer {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .beansCardShadow(radius: 10, y: 4)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
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

    /// 每日推荐：主题渐变晕染大卡 + 播放/随机 + 前 3 首带序号
    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "每日推荐", trailing: "查看全部") {
                BeansHaptics.tap()
                showDailyList = true
            }
            // 每日推荐大卡：点击查看今日全部推荐
            Button {
                BeansHaptics.tap()
                showDailyList = true
            } label: {
                HStack(spacing: 14) {
                    CoverImage(url: dailySongs.first?.coverURL, size: 64, cornerRadius: 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("为你精选 \(dailySongs.count) 首")
                            .font(BeansFont.appFont(17, .bold))
                            .foregroundStyle(Color.beansLabel)
                        Text("每日更新 · 按你的口味推荐")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            LinearGradient(colors: AccentTheme.current.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .padding(14)
                .background {
                    GlassEffectContainer {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .beansCardShadow(radius: 10, y: 4)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.97))

            // 播放全部 / 随机播放
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

            // 今日推荐前 3 首：序号 + 歌曲行
            VStack(spacing: 0) {
                ForEach(Array(dailySongs.prefix(3).enumerated()), id: \.element.id) { index, song in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(BeansFont.appFont(14, .bold, .rounded))
                            .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansSecondary)
                            .frame(width: 22)
                        SongCell(song: song) {
                            BeansHaptics.tap()
                            player.play(songs: dailySongs, startAt: index)
                        }
                    }
                    .padding(.horizontal, 14)
                    Divider().overlay(Color.beansSecondary.opacity(0.15))
                }
            }
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

    /// 歌单广场：横向滑动大卡
    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "歌单广场")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(personalized) { playlist in
                        Button {
                            if source == .qq {
                                selectedQQPlaylist = playlist
                            } else {
                                selectedPlaylist = playlist
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CoverImage(url: playlist.coverURL, size: 120, cornerRadius: 18)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 26, height: 26)
                                            .background(.black.opacity(0.4), in: Circle())
                                            .padding(8)
                                    }
                                Text(playlist.name)
                                    .font(BeansFont.appFont(12, .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 120, alignment: .leading)
                            }
                            .padding(8)
                            .background {
                                GlassEffectContainer {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(.clear)
                                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                }
                            }
                            .beansCardShadow(radius: 10, y: 4)
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
                    }
                }
                .padding(.vertical, 2)
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
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: tracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: tracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
                            SongCell(song: song, glassRow: true) {
                                BeansHaptics.tap()
                                player.play(songs: songs, startAt: index)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: tracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
                    .font(BeansFont.appFont(18, .bold))
                    .foregroundStyle(Color.beansLabel)
                Text(topList.updateFrequency)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansSecondary)
                Text("\(tracks.count) 首")
                    .font(BeansFont.appFont(12))
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
