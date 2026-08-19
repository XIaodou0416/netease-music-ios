import SwiftUI
import UIKit

/// 通用歌曲行：点击播放，长按弹出操作菜单
struct SongCell: View {
    let song: Song
    var index: Int? = nil
    var showIndex = false
    var action: () -> Void

    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @State private var showAddSheet = false
    @State private var isLiked = false
    @State private var toast: String?

    private var isCurrent: Bool {
        player.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if showIndex, let index {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.beansSecondary)
                        .frame(width: 24)
                }
                AsyncImage(url: song.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.beansCard)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.body)
                        .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                        .lineLimit(1)
                    Text(song.artists)
                        .font(.caption)
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: player.isPlaying ? "waveform" : "pause.circle")
                        .foregroundStyle(Color.beansAmber)
                } else {
                    Text(song.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(Color.beansSecondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.badge.plus")
            }
            Button {
                toggleLike()
            } label: {
                Label(isLiked ? "取消收藏" : "收藏", systemImage: isLiked ? "heart.slash" : "heart")
            }
            Button {
                showAddSheet = true
            } label: {
                Label("添加到歌单", systemImage: "plus.circle")
            }
            ShareLink(item: "\(song.name) - \(song.artists)（来自 Beans）") {
                Label("分享歌曲", systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.string = song.name
                toast = "已复制歌名"
            } label: {
                Label("复制歌名", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddToPlaylistSheet(song: song)
                .presentationDetents([.medium])
        }
        .beansToast(message: $toast)
    }

    private func toggleLike() {
        isLiked.toggle()
        Task {
            let ok = (try? await NetEaseAPI.shared.like(id: song.id, liked: isLiked)) ?? false
            if !ok {
                await MainActor.run {
                    self.isLiked.toggle()
                    self.toast = "操作失败，请确认已登录"
                }
            }
        }
    }
}