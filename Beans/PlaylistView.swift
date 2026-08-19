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
            } else if songs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.beansSecondary)
                    Text("歌单里还没有歌曲")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song, index: index, showIndex: true) {
                            player.play(songs: songs, startAt: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .background(Color.beansBackground.ignoresSafeArea())
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard songs.isEmpty else { return }
            songs = (try? await NetEaseAPI.shared.playlistTracks(id: playlist.id)) ?? []
            isLoading = false
        }
    }
}