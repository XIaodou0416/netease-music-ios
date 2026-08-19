import SwiftUI

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var newName = ""
    @State private var toast: String?

    var body: some View {
        // 修复：sheet 内需要独立玻璃采样容器，否则玻璃组件渲染空白/糊块
        GlassEffectContainer {
        NavigationStack {
            Group {
                if auth.isLoggedIn {
                    List {
                        Section("添加到歌单") {
                            ForEach(auth.playlists.filter { $0.id != auth.favoritePlaylistID }) { playlist in
                                Button {
                                    Task { await add(playlistID: playlist.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        AsyncImage(url: playlist.coverURL) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Rectangle().fill(Color.beansCard)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Text(playlist.name)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.beansLabel)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                        Section("新建歌单") {
                            HStack {
                                TextField("歌单名称", text: $newName)
                                Button("创建并添加") {
                                    Task { await createAndAdd() }
                                }
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.beansSecondary)
                        Text("登录后才能添加到歌单")
                            .font(.headline)
                            .foregroundStyle(Color.beansLabel)
                        Text("请先在「我的」页扫码登录")
                            .font(.footnote)
                            .foregroundStyle(Color.beansSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationTitle("\(song.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .beansToast(message: $toast)
        }
        }
    }

    private func add(playlistID: Int) async {
        let ok = (try? await NetEaseAPI.shared.addToPlaylist(playlistID: playlistID, songIDs: [song.id])) ?? false
        toast = ok ? "已添加到歌单" : "添加失败"
        if ok {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }

    private func createAndAdd() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let id = try await NetEaseAPI.shared.createPlaylist(name: name)
            if let user = auth.user {
                auth.playlists = (try? await NetEaseAPI.shared.userPlaylists(uid: user.uid)) ?? auth.playlists
            }
            _ = try await NetEaseAPI.shared.addToPlaylist(playlistID: id, songIDs: [song.id])
            toast = "已创建并添加"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } catch {
            toast = error.localizedDescription
        }
    }
}