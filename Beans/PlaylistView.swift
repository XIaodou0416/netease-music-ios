import SwiftUI

struct PlaylistView: View {
    let playlist: Playlist
    @EnvironmentObject private var player: PlayerManager
    @State private var songs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongRow(song: song, index: index) {
                            player.play(songs: songs, startAt: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .background(Color.beansBackground.ignoresSafeArea())
        .task {
            guard songs.isEmpty else { return }
            songs = (try? await NetEaseAPI.shared.playlistTracks(id: playlist.id)) ?? []
            isLoading = false
        }
    }
}

struct SongRow: View {
    let song: Song
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.beansMuted)
                    .frame(width: 24)
                AsyncImage(url: song.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.white.opacity(0.07))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name).font(.body).foregroundStyle(Color.beansCream).lineLimit(1)
                    Text(song.artists).font(.caption).foregroundStyle(Color.beansMuted).lineLimit(1)
                }
                Spacer()
                Text(song.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(Color.beansMuted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}