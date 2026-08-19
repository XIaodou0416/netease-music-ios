import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.beansSecondary)
                        Text("队列为空")
                            .font(.headline)
                            .foregroundStyle(Color.beansLabel)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, song in
                                HStack(spacing: 12) {
                                    Button {
                                        player.playQueueIndex(index)
                                    } label: {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: song.coverURL) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Rectangle().fill(Color.beansCard)
                                            }
                                            .frame(width: 42, height: 42)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(song.name)
                                                    .font(.subheadline.weight(index == player.currentIndex ? .semibold : .regular))
                                                    .foregroundStyle(index == player.currentIndex ? Color.beansAmber : Color.beansLabel)
                                                    .lineLimit(1)
                                                Text(song.artists)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.beansSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                    if index == player.currentIndex {
                                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.circle")
                                            .foregroundStyle(Color.beansAmber)
                                    }
                                    if player.queue.count > 1 {
                                        Button {
                                            player.removeFromQueue(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.beansSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(.regular)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                                )
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
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }
}