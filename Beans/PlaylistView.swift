import SwiftUI

struct PlaylistView: View {
    let playlist: Playlist
    @EnvironmentObject private var player: PlayerManager
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                // 修复：接口异常时展示错误 + 重试，而不是显示"歌单里还没有歌曲"误导
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.beansSecondary)
                    Text("歌单加载失败")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                    Text("请检查网络后重试")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                    Button {
                        Task { await load() }
                    } label: {
                        Label("重新加载", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.beansLabel)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.beansGlassFill)
                            .glassEffect(.regular)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.beansGlassFill)
                            .glassEffect(.regular)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song, index: index, showIndex: true) {
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
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard songs.isEmpty, !loadFailed else { return }
            await load()
        }
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            songs = try await NetEaseAPI.shared.playlistTracks(id: playlist.id)
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}