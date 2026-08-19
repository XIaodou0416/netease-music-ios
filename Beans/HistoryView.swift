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
                        Button {
                            player.play(songs: player.history, startAt: index)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: song.coverURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.beansCard)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name).font(.body).foregroundStyle(Color.beansLabel).lineLimit(1)
                                    Text(song.artists).font(.caption).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                }
                                Spacer()
                                if song.id == player.currentSong?.id {
                                    Image(systemName: player.isPlaying ? "waveform" : "pause.circle")
                                        .foregroundStyle(Color.beansAmber)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
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