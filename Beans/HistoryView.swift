import SwiftUI

// 最近播放（全新布局）
struct HistoryView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        Group {
            if player.history.isEmpty {
                BeansEmpty(icon: "clock.arrow.circlepath", title: "还没有播放记录", subtitle: "播放过的歌曲会出现在这里")
            } else {
                List {
                    ForEach(Array(player.history.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song) {
                            player.play(songs: player.history, startAt: index)
                        }
                    }
                }
                .beansList()
            }
        }
        .beansPage()
        .navigationTitle("最近播放")
        .navigationBarTitleDisplayMode(.large)
    }
}