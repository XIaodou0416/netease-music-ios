import SwiftUI

struct PlaylistView: View {
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
                        header
                        Section {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song, showLike: auth.isLoggedIn) {
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CoverImage(url: playlist.coverURL, size: 96, cornerRadius: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(2)
                    if !playlist.creatorName.isEmpty {
                        Text(playlist.creatorName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansSecondary)
                    }
                    Text("\(tracks.count) 首")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                    player.play(songs: tracks, startAt: 0)
                }
                GlassButton(title: "随机播放", systemName: "shuffle") {
                    player.play(songs: tracks, startAt: Int.random(in: 0..<tracks.count))
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await NetEaseAPI.shared.playlistTracks(id: playlist.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}