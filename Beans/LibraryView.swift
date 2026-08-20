import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager

    @State private var showHistory = false
    @State private var selectedPlaylist: Playlist?
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var pendingDelete: Playlist?
    @State private var showDeleteConfirm = false

    var body: some View {
        let _ = theme.accent
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
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
        .alert("新建歌单", isPresented: $showCreatePlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") { createPlaylist() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入歌单名称，创建后同步到网易云")
        }
        .confirmationDialog("确定删除歌单「\(pendingDelete?.name ?? "")」吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { confirmDeletePlaylist() }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("音乐库")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                Text("\(auth.playlists.count) 个歌单")
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

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的歌单", trailing: "新建") {
                BeansHaptics.tap()
                newPlaylistName = ""
                showCreatePlaylist = true
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                if auth.playlists.isEmpty {
                    createPlaylistCard
                        .gridCellColumns(2)
                } else {
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
                        .contextMenu {
                            Button {
                                BeansHaptics.tap()
                                requestDelete(playlist)
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }
                    }
                    createPlaylistCard
                }
            }
        }
    }

    private var createPlaylistCard: some View {
        Button {
            BeansHaptics.tap()
            newPlaylistName = ""
            showCreatePlaylist = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.beansSecondary.opacity(0.45))
                        .frame(width: 160, height: 160)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.beansSecondary)
                }
                Text("新建歌单")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.beansSecondary)
            }
        }
        .buttonStyle(.plain)
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
                        SongCell(song: song) {
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

    // MARK: - 歌单新建 / 删除

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            ToastCenter.shared.show("请输入歌单名称")
            return
        }
        guard auth.isLoggedIn else {
            ToastCenter.shared.show("请先登录后再创建歌单")
            return
        }
        Task {
            do {
                _ = try await NetEaseAPI.shared.createPlaylist(name: name)
                ToastCenter.shared.show("歌单「\(name)」已创建")
                newPlaylistName = ""
                await auth.loadLibrary()
            } catch {
                ToastCenter.shared.show("创建失败：\(error.localizedDescription)")
            }
        }
    }

    private func requestDelete(_ playlist: Playlist) {
        pendingDelete = playlist
        showDeleteConfirm = true
    }

    private func confirmDeletePlaylist() {
        guard let playlist = pendingDelete else { return }
        Task {
            do {
                let ok = try await NetEaseAPI.shared.deletePlaylist(id: playlist.id)
                if ok {
                    ToastCenter.shared.show("已删除歌单「\(playlist.name)」")
                    await auth.loadLibrary()
                } else {
                    ToastCenter.shared.show("删除失败，请稍后再试")
                }
            } catch {
                ToastCenter.shared.show("删除失败：\(error.localizedDescription)")
            }
        }
    }

    private func playFromHistory(_ song: Song) {
        if let index = player.history.firstIndex(of: song) {
            player.play(songs: player.history, startAt: index)
        }
    }
}
