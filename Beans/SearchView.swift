import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @State private var keyword = ""
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var searched = false
    @State private var showAddSheet = false
    @State private var selectedSong: Song?

    var body: some View {
        Group {
            if songs.isEmpty && !searched {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.beansSecondary)
                    Text("搜索网易云曲库")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                    Text("输入歌名、歌手或专辑名")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            Button {
                                player.play(songs: songs, startAt: index)
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncImage(url: song.coverURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.beansCard)
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.name).font(.body).foregroundStyle(Color.beansLabel).lineLimit(1)
                                        Text(song.artists).font(.caption).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                selectedSong = song
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title3)
                                    .foregroundStyle(Color.beansSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
        }
        .background(Color.beansBackground.ignoresSafeArea())
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $keyword, prompt: "歌名 / 歌手 / 专辑")
        .onSubmit(of: .search) { runSearch() }
        .sheet(item: $selectedSong) { song in
            AddToPlaylistSheet(song: song)
                .presentationDetents([.medium])
        }
    }

    private func runSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searched = true
        isLoading = true
        Task {
            defer { isLoading = false }
            songs = (try? await NetEaseAPI.shared.search(keyword: trimmed)) ?? []
        }
    }
}

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var newName = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            Group {
                if auth.isLoggedIn {
                    List {
                        Section("添加到歌单") {
                            ForEach(auth.playlists.filter { $0.id != auth.favoritePlaylistID }) { playlist in
                                Button {
                                    Task { await add(playlistID: playlist.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        AsyncImage(url: playlist.coverURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Rectangle().fill(Color.beansCard)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Text(playlist.name)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.beansLabel)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        Section("新建歌单") {
                            HStack {
                                TextField("歌单名称", text: $newName)
                                Button("创建并添加") {
                                    Task { await createAndAdd() }
                                }
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.beansSecondary)
                        Text("登录后才能添加到歌单")
                            .font(.headline)
                            .foregroundStyle(Color.beansLabel)
                        Text("请先在「我的」页扫码登录")
                            .font(.footnote)
                            .foregroundStyle(Color.beansSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationTitle("\(song.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .beansToast(message: $toast)
        }
    }

    private func add(playlistID: Int) async {
        let ok = (try? await NetEaseAPI.shared.addToPlaylist(playlistID: playlistID, songIDs: [song.id])) ?? false
        toast = ok ? "已添加到歌单" : "添加失败"
        if ok {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }

    private func createAndAdd() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let id = try await NetEaseAPI.shared.createPlaylist(name: name)
            if let user = auth.user {
                auth.playlists = (try? await NetEaseAPI.shared.userPlaylists(uid: user.uid)) ?? auth.playlists
            }
            _ = try await NetEaseAPI.shared.addToPlaylist(playlistID: id, songIDs: [song.id])
            toast = "已创建并添加"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            toast = error.localizedDescription
        }
    }
}