import SwiftUI

struct SimiSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let songID: Int
    @State private var songs: [Song] = []

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song) {
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
            .navigationTitle("相似歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                songs = (try? await NetEaseAPI.shared.simiSongs(id: songID)) ?? []
            }
        }
        .presentationDragIndicator(.hidden)
    }
}