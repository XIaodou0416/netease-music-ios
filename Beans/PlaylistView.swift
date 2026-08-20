import SwiftUI

struct PlaylistView: View {
    let playlist: Playlist
    @EnvironmentObject private var player: PlayerManager
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                BeansErrorState(title: "歌单加载失败") {
                    Task { await load() }
                }
            } else if songs.isEmpty {
                BeansEmptyState(icon: "music.note.list", title: "歌单里还没有歌曲", subtitle: "换个歌单试试吧")
            } else {
                List {
                    Section {
                        Button {
                            player.play(songs: songs, startAt: 0)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Color.beansAmber, in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("播放全部").font(.headline).foregroundStyle(Color.beansLabel)
                                    Text("共 \(songs.count) 首")
                                        .font(.caption)
                                        .foregroundStyle(Color.beansSecondary)
                                }
                                Spacer(minLength: 8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .beansRowCard(cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song, index: index, showIndex: true) {
                            player.play(songs: songs, startAt: index)
                        }
                    }
                }
                .beansListStyle()
            }
        }
        .beansPageBackground()
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard songs.isEmpty, !loadFailed else { return }
            await load()
        }
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            songs = try await NetEaseAPI.shared.playlistTracks(id: playlist.id)
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}