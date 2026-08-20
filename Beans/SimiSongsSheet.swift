import SwiftUI

// 相似歌曲（全新布局）
struct SimiSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    let songID: Int
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        GlassEffectContainer {
            NavigationStack {
                Group {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if loadFailed {
                        BeansError(title: "相似歌曲加载失败") {
                            Task { await load() }
                        }
                    } else if songs.isEmpty {
                        BeansEmpty(icon: "sparkles", title: "暂无相似歌曲", subtitle: "试试其它歌曲吧")
                    } else {
                        List {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                SongCell(song: song) {
                                    player.play(songs: songs, startAt: index)
                                }
                            }
                        }
                        .beansList()
                    }
                }
                .beansPage()
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
        isLoading = true
        loadFailed = false
        do {
            songs = try await NetEaseAPI.shared.simiSongs(id: songID)
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}