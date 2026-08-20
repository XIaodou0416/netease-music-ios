import SwiftUI

// 播放队列（全新布局）
struct QueueView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassEffectContainer {
            NavigationStack {
                Group {
                    if player.queue.isEmpty {
                        BeansEmpty(icon: "music.note", title: "队列为空", subtitle: "从歌单或搜索中添加歌曲")
                    } else {
                        List {
                            Section {
                                ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                                    HStack(spacing: 12) {
                                        Button {
                                            player.playQueueIndex(index)
                                        } label: {
                                            HStack(spacing: 12) {
                                                BeansCover(url: song.coverURL, radius: 8).frame(width: 42, height: 42)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(song.name)
                                                        .font(.subheadline.weight(index == player.currentIndex ? .semibold : .regular))
                                                        .foregroundStyle(index == player.currentIndex ? Color.beansAmber : Color.beansLabel)
                                                        .lineLimit(1)
                                                    Text(song.artists).font(.caption).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        Spacer(minLength: 8)
                                        if index == player.currentIndex {
                                            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.circle")
                                                .foregroundStyle(Color.beansAmber)
                                        }
                                        if player.queue.count > 1 {
                                            Button {
                                                player.removeFromQueue(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.beansSecondary)
                                                    .frame(width: 30, height: 30)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .beansRow()
                                }
                            } header: {
                                Text("\(player.queue.count) 首 · \(player.playMode.title)")
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .beansPage()
                .navigationTitle("播放队列")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }
}