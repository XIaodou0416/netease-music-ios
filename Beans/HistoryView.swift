import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        NavigationStack {
            Group {
                if player.history.isEmpty {
                    EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放历史")
                } else {
                    List {
                        ForEach(Array(player.history.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song, showLike: false) {
                                player.play(songs: player.history, startAt: index)
                            }
                        }
                    }
                }
            }
            .navigationTitle("最近播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !player.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空") {
                            player.clearHistory()
                        }
                    }
                }
            }
        }
    }
}