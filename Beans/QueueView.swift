import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = theme.accent
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "播放队列为空")
                } else {
                    List {
                        Section("接下来 (\(player.queue.count) 首)") {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                                row(song, index: index)
                            }
                            .onDelete { offsets in
                                let indices = offsets.map { $0 }
                                for index in indices.sorted(by: >) where player.queue.indices.contains(index) {
                                    player.removeFromQueue(at: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            player.clearQueue()
                        } label: {
                            Label("清空队列", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ song: Song, index: Int) -> some View {
        let isCurrent = index == player.currentIndex
        HStack(spacing: 12) {
            CoverImage(url: song.coverURL, size: 42, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.custom(BeansFont.name, size: 15).weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                Text(song.artists)
                    .font(.custom(BeansFont.name, size: 12))
                    .foregroundStyle(Color.beansSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if isCurrent {
                if player.isPlaying {
                    NowPlayingIndicator()
                } else {
                    Image(systemName: "pause.fill")
                        .font(.custom(BeansFont.name, size: 12))
                        .foregroundStyle(Color.beansAmber)
                }
            } else {
                Text(song.formattedDuration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.beansSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if player.queue.indices.contains(index) {
                player.playQueueIndex(index)
            }
        }
    }
}
