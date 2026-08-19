import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        Group {
            if player.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.beansSecondary)
                    Text("还没有播放记录")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                    Text("播放过的歌曲会出现在这里")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(player.history.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song) {
                            player.play(songs: player.history, startAt: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.beansBackground.ignoresSafeArea())
        .navigationTitle("最近播放")
        .navigationBarTitleDisplayMode(.large)
    }
}