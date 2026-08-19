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
                            .padding(.vertical, 6)
                        }
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            player.play(songs: songs, startAt: index)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.beansSecondary)
                                    .frame(width: 24)
                                AsyncImage(url: song.coverURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.beansCard)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.body)
                                        .foregroundStyle(song.id == player.currentSong?.id ? Color.beansAmber : Color.beansLabel)
                                        .lineLimit(1)
                                    Text(song.artists).font(.caption).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                }
                                Spacer()
                                if song.id == player.currentSong?.id {
                                    Image(systemName: player.isPlaying ? "waveform" : "pause.circle")
                                        .foregroundStyle(Color.beansAmber)
                                } else {
                                    Text(song.formattedDuration)
                                        .font(.caption)
                                        .foregroundStyle(Color.beansSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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