import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager

    @State private var topLists: [TopList] = []
    @State private var dailySongs: [Song] = []
    @State private var personalized: [Playlist] = []

    @State private var hotPlaylists: [Playlist] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var selectedTopList: TopList?
    @State private var selectedPlaylist: Playlist?
    @State private var showDailyList = false

    var body: some View {
        let _ = theme.accent
        ZStack {
            // 仅主页模式：自定义背景只应用在发现页（图片优先，其次颜色）
            if !theme.backgroundSyncAll, let image = theme.customBackgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [.black.opacity(0.30), .black.opacity(0.52)],
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
                    if !topLists.isEmpty {
                        topListsSection
                    }
                    if !dailySongs.isEmpty {
                        dailySection
                    }
                    if !personalized.isEmpty {
                        personalizedSection
                    }

                    if !hotPlaylists.isEmpty {
                        hotPlaylistsSection
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .task { await load() }
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
            .sheet(isPresented: $showDailyList) {
                DailySongsSheet(songs: dailySongs)
                    .environmentObject(player)
                    .environmentObject(auth)
            }
        }
    }

    private var header: some View {
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
        .padding(.top, 8)
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(topLists) { topList in
                        Button {
                            selectedTopList = topList
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CoverImage(url: topList.coverURL, size: 120, cornerRadius: 16)
                                Text(topList.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
            SectionHeader(title: "推荐歌单")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(personalized) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CoverImage(url: playlist.coverURL, size: 160, cornerRadius: 16)
                                .frame(maxWidth: .infinity)
                            Text(playlist.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    private var hotPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "热门歌单")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(hotPlaylists) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CoverImage(url: playlist.coverURL, size: 160, cornerRadius: 16)
                                .frame(maxWidth: .infinity)
                            Text(playlist.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
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
        async let a = NetEaseAPI.shared.topLists()
        async let b = NetEaseAPI.shared.dailyRecommend()
        async let c = NetEaseAPI.shared.personalizedPlaylists(limit: 10)
        async let d = NetEaseAPI.shared.topPlaylists(limit: 10)
        do {
            let (tl, dr, pp, hp) = try await (a, b, c, d)
            topLists = tl
            dailySongs = dr
            personalized = pp
            hotPlaylists = hp
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
