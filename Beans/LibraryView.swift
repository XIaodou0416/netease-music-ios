import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager

    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var selectedPlaylist: Playlist?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                favoritesCard
                playlistsSection
                historySection
                topPlayedSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }
        .scrollIndicators(.hidden)
        .refreshable { await auth.loadLibrary() }
        .task { await auth.loadLibrary() }
        .sheet(isPresented: $showFavorites) {
            FavoritesView()
                .environmentObject(auth)
                .environmentObject(player)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
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
                Text("音乐库")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                Text("\(auth.playlists.count) 个歌单 · \(auth.displayedFavoriteCount) 首收藏")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansSecondary)
            }
            Spacer()
            GlassIconButton(systemName: "arrow.clockwise") {
                Task { await auth.loadLibrary() }
            }
        }
        .padding(.top, 8)
    }

    private var favoritesCard: some View {
        Button {
            showFavorites = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient.beansAccent)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("我喜欢的音乐")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("\(auth.displayedFavoriteCount) 首")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary)
            }
            .padding(14)
            .glassEffect(.clear, in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的歌单")
            if auth.playlists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: "暂无歌单")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(auth.playlists) { playlist in
                        Button {
                            selectedPlaylist = playlist
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CoverImage(url: playlist.coverURL, size: 160, cornerRadius: 16)
                                    .frame(maxWidth: .infinity)
                                Text(playlist.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                Text("\(playlist.trackCount) 首")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.beansSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近播放", trailing: "查看全部") {
                showHistory = true
            }
            if player.history.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(player.history.prefix(5)) { song in
                        SongCell(song: song, showLike: false) {
                            playFromHistory(song)
                        }
                        Divider().overlay(Color.beansSecondary.opacity(0.15))
                    }
                }
            }
        }
    }

    private var topPlayedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "听歌排行")
            let top = player.topPlayed
            if top.isEmpty {
                EmptyStateView(icon: "chart.bar.fill", text: "多听几首再来看看吧")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.element.song.id) { index, entry in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansSecondary)
                                .frame(width: 22)
                            CoverImage(url: entry.song.coverURL, size: 44, cornerRadius: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.song.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                Text("播放 \(entry.count) 次")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.beansSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.play(songs: top.map(\.song), startAt: index)
                        }
                        Divider().overlay(Color.beansSecondary.opacity(0.15))
                    }
                }
            }
        }
    }

    private func playFromHistory(_ song: Song) {
        if let index = player.history.firstIndex(of: song) {
            player.play(songs: player.history, startAt: index)
        }
    }
}

// MARK: - 我喜欢的音乐

struct FavoritesView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        NavigationStack {
            Group {
                if auth.favoriteTracks.isEmpty {
                    EmptyStateView(icon: "heart", text: "还没有收藏的歌曲")
                } else {
                    List {
                        HStack(spacing: 12) {
                            GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                player.play(songs: auth.favoriteTracks, startAt: 0)
                            }
                            GlassButton(title: "随机播放", systemName: "shuffle") {
                                player.play(songs: auth.favoriteTracks, startAt: Int.random(in: 0..<auth.favoriteTracks.count))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)

                        Section {
                            ForEach(Array(auth.favoriteTracks.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song) {
                                    player.play(songs: auth.favoriteTracks, startAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我喜欢的音乐")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}