import SwiftUI

struct SimiSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let songID: Int
    @State private var songs: [Song] = []
    @State private var loadFailed = false

    var body: some View {
        // 修复：sheet 内需要独立玻璃采样容器，避免玻璃组件空白
        GlassEffectContainer {
            NavigationStack {
                Group {
                    if songs.isEmpty && !loadFailed {
                        // 修复：原先失败/空数据时一直转圈卡死；拆分为加载中与失败两种状态
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if loadFailed {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.beansSecondary)
                            Text("相似歌曲加载失败")
                                .font(.headline)
                                .foregroundStyle(Color.beansLabel)
                            Button("重新加载") {
                                Task { await load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.beansAmber)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if songs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.beansSecondary)
                            Text("暂无相似歌曲")
                                .font(.headline)
                                .foregroundStyle(Color.beansLabel)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    guard songs.isEmpty else { return }
                    await load()
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }

    private func load() async {
        loadFailed = false
        do {
            songs = try await NetEaseAPI.shared.simiSongs(id: songID)
        } catch {
            loadFailed = true
        }
    }
}