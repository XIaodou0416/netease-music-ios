import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager

    @State private var topLists: [TopList] = []
    @State private var dailySongs: [Song] = []
    @State private var personalized: [Playlist] = []
    @State private var newSongs: [Song] = []
    @State private var hotPlaylists: [Playlist] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var selectedTopList: TopList?
    @State private var selectedPlaylist: Playlist?
    @State private var showingFM = false

    var body: some View {
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
                    quickActions
                    if !topLists.isEmpty {
                        topListsSection
                    }
                    if !dailySongs.isEmpty {
                        dailySection
                    }
                    if !personalized.isEmpty {
                        personalizedSection
                    }
                    if !newSongs.isEmpty {
                        newSongsSection
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

    private var quickActions: some View {
        HStack(spacing: 12) {
            GlassButton(title: "每日推荐", systemName: "calendar.badge.clock", prominent: true) {
                playDaily()
            }
            GlassButton(title: "私人FM", systemName: "dot.radiowaves.left.and.right") {
                startFM()
            }
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
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "每日推荐")
            VStack(spacing: 0) {
                ForEach(Array(dailySongs.enumerated()), id: \.element.id) { index, song in
                    SongCell(song: song) {
                        player.play(songs: dailySongs, startAt: index)
                    }
                    Divider().overlay(Color.beansSecondary.opacity(0.15))
                }
            }
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

    private var newSongsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "新歌速递")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(newSongs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            player.play(songs: newSongs, startAt: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CoverImage(url: song.coverURL, size: 100, cornerRadius: 14)
                                Text(song.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                    .frame(width: 100, alignment: .leading)
                                Text(song.artists)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.beansSecondary)
                                    .lineLimit(1)
                                    .frame(width: 100, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
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

    private func playDaily() {
        guard !dailySongs.isEmpty else {
            Task { await load() }
            return
        }
        player.play(songs: dailySongs, startAt: 0)
    }

    private func startFM() {
        Task {
            if let songs = try? await NetEaseAPI.shared.personalFM(), !songs.isEmpty {
                await MainActor.run {
                    player.play(songs: songs, startAt: 0)
                }
            }
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        async let a = NetEaseAPI.shared.topLists()
        async let b = NetEaseAPI.shared.dailyRecommend()
        async let c = NetEaseAPI.shared.personalizedPlaylists(limit: 10)
        async let d = NetEaseAPI.shared.newSongs(limit: 10)
        async let e = NetEaseAPI.shared.topPlaylists(limit: 10)
        do {
            let (tl, dr, pp, ns, hp) = try await (a, b, c, d, e)
            topLists = tl
            dailySongs = dr
            personalized = pp
            newSongs = ns
            hotPlaylists = hp
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - 排行榜详情

struct TopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
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