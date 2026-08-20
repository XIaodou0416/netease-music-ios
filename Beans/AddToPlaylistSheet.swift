import SwiftUI

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var newName = ""
    @State private var toast: String?

    var body: some View {
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
                                            BeansCover(url: playlist.coverURL, cornerRadius: 8)
                                                .frame(width: 40, height: 40)
                                            Text(playlist.name)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.beansLabel)
                                            Spacer(minLength: 8)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .beansRowCard(cornerRadius: 14)
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
                        BeansEmptyState(icon: "person.crop.circle.badge.exclamationmark", title: "登录后才能添加到歌单", subtitle: "请先在「我的」页扫码登录")
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .beansPageBackground()
                .navigationTitle(song.name)
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