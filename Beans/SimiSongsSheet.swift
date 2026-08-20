import SwiftUI

struct SimiSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    @State private var songs: [Song] = []
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
                } else if songs.isEmpty {
                    EmptyStateView(icon: "sparkles", text: "暂无相似歌曲")
                } else {
                    List {
                        Section("根据《\(player.currentSong?.name ?? "")》推荐") {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song, showLike: auth.isLoggedIn) {
                                    player.play(songs: songs, startAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("相似歌曲")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: player.currentSong?.id) { await load() }
    }

    private func load() async {
        guard let song = player.currentSong else {
            loading = false
            return
        }
        loading = true
        errorMessage = nil
        do {
            songs = try await NetEaseAPI.shared.simiSongs(id: song.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}