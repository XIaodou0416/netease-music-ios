import SwiftUI

// 音乐库主页（全新布局：标题 + 收藏 + 发现，无自定义底栏）
struct LibraryView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @State private var selectedPlaylist: Playlist?
    @State private var loaded = false
    @State private var topLists: [TopList] = []
    @State private var recommended: [Playlist] = []
    @State private var newSongs: [Song] = []
    @State private var topPlaylists: [Playlist] = []
    @State private var showSearch = false
    @State private var toast: String?

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    title
                    if auth.isLoggedIn {
                        if auth.playlists.isEmpty && !loaded {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                        } else {
                            favoriteCard
                            myPlaylists
                        }
                    } else {
                        loginCard
                    }
                    discover
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)   // 底部留出迷你播放器空间
            }
            .beansPage()
            .refreshable { await refreshAll() }
            .navigationDestination(item: $selectedPlaylist) { PlaylistView(playlist: $0) }
            .navigationDestination(isPresented: $showSearch) { SearchView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.beansLabel)
                    }
                }
            }
            .task { await refreshAll(); loaded = true }
        }
        .beansToast(message: $toast)
    }

    // MARK: - 标题

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("音乐库")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.beansLabel)
            Text(auth.user?.nickname ?? "发现好歌，登录同步收藏")
                .font(.footnote)
                .foregroundStyle(Color.beansSecondary)
                .lineLimit(1)
        }
        .padding(.top, 8)
    }

    // MARK: - 登录卡

    private var loginCard: some View {
        Button {
            NotificationCenter.default.post(name: .init("beans.openLogin"), object: nil)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.beansAmber)
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录同步你的收藏").font(.headline).foregroundStyle(Color.beansLabel)
                    Text("扫码登录后，歌单和喜欢的音乐会出现在这里").font(.caption).foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Color.beansSecondary)
            }
        }
        .buttonStyle(.plain)
        .beansGlass(padding: 16)
    }

    // MARK: - 我喜欢的音乐

    private var favoriteCard: some View {
        Button {
            if !auth.favoriteTracks.isEmpty {
                player.play(songs: auth.favoriteTracks, startAt: 0)
            } else {
                toast = "「我喜欢的音乐」暂无歌曲"
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [.pink, .orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "heart.fill").font(.title).foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("我喜欢的音乐").font(.headline).foregroundStyle(Color.beansLabel)
                    Text("\(auth.favoriteTracks.count) 首 · 点按播放").font(.caption).foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.circle.fill").font(.system(size: 32)).foregroundStyle(Color.beansAmber)
            }
        }
        .buttonStyle(.plain)
        .beansGlass(padding: 14)
    }

    // MARK: - 我的歌单

    private var myPlaylists: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的歌单").font(.title3.bold()).foregroundStyle(Color.beansLabel)
                Spacer()
                Button {
                    Task { await createPlaylist() }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: grid, spacing: 16) {
                ForEach(auth.playlists.filter { $0.id != auth.favoritePlaylistID }) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            BeansCover(url: playlist.coverURL)
                            Text(playlist.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(2, reservesSpace: true)
                                .multilineTextAlignment(.leading)
                            Text("\(playlist.trackCount) 首").font(.caption2).foregroundStyle(Color.beansSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func createPlaylist() async {
        let name = "Beans 歌单 \(Int(Date().timeIntervalSince1970) % 10000)"
        do {
            _ = try await NetEaseAPI.shared.createPlaylist(name: name)
            toast = "已创建歌单「\(name)」"
            if let user = auth.user {
                auth.playlists = (try? await NetEaseAPI.shared.userPlaylists(uid: user.uid)) ?? auth.playlists
            }
        } catch {
            toast = error.localizedDescription
        }
    }

    // MARK: - 发现

    private var discover: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("发现").font(.title3.bold()).foregroundStyle(Color.beansLabel)

            if topLists.isEmpty && newSongs.isEmpty && recommended.isEmpty && topPlaylists.isEmpty {
                BeansEmpty(icon: "music.note", title: "发现内容加载失败", subtitle: "下拉刷新或检查网络")
                    .frame(minHeight: 200)
            }

            if auth.isLoggedIn {
                HStack(spacing: 12) {
                    quickCard(icon: "sparkles", tint: [Color.blue, .purple], title: "每日推荐", subtitle: "30 首") {
                        Task { await playDaily() }
                    }
                    quickCard(icon: "radio", tint: [Color.green, .teal], title: "私人 FM", subtitle: "猜你喜欢") {
                        Task { await playFM() }
                    }
                }
            }

            if !topLists.isEmpty {
                sectionTitle("排行榜")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(topLists) { top in
                            Button {
                                selectedPlaylist = Playlist(id: top.id, name: top.name, coverURL: top.coverURL)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    BeansCover(url: top.coverURL)
                                        .frame(width: 112, height: 112)
                                    Text(top.name).font(.caption.weight(.medium)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                    Text(top.updateFrequency).font(.caption2).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                }
                                .frame(width: 112)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !newSongs.isEmpty {
                sectionTitle("新歌速递")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(newSongs) { song in
                            Button {
                                player.play(songs: newSongs, startAt: newSongs.firstIndex(of: song) ?? 0)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    BeansCover(url: song.coverURL)
                                        .frame(width: 112, height: 112)
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(Color.beansAmber).padding(5)
                                        }
                                    Text(song.name).font(.caption.weight(.medium)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                    Text(song.artists).font(.caption2).foregroundStyle(Color.beansSecondary).lineLimit(1)
                                }
                                .frame(width: 112)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !recommended.isEmpty {
                sectionTitle("推荐歌单")
                LazyVGrid(columns: grid, spacing: 16) {
                    ForEach(recommended) { playlist in
                        Button {
                            selectedPlaylist = playlist
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                BeansCover(url: playlist.coverURL)
                                Text(playlist.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !topPlaylists.isEmpty {
                sectionTitle("精品歌单")
                LazyVGrid(columns: grid, spacing: 16) {
                    ForEach(topPlaylists) { playlist in
                        Button {
                            selectedPlaylist = playlist
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                BeansCover(url: playlist.coverURL)
                                Text(playlist.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.leading)
                                Text("\(playlist.trackCount) 首").font(.caption2).foregroundStyle(Color.beansSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline).foregroundStyle(Color.beansLabel)
    }

    private func quickCard(icon: String, tint: [Color], title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.beansLabel)
                    Text(subtitle).font(.caption2).foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 4)
            }
        }
        .buttonStyle(.plain)
        .beansGlass(radius: 18, padding: 12)
    }

    // MARK: - 数据

    private func refreshAll() async {
        async let a: Void = loadTopLists()
        async let b: Void = loadRecommended()
        async let c: Void = loadNewSongs()
        async let d: Void = loadTopPlaylists()
        _ = await (a, b, c, d)
        if auth.isLoggedIn {
            await auth.loadLibrary()
        }
    }

    private func loadTopLists() async { topLists = (try? await NetEaseAPI.shared.topLists()) ?? [] }
    private func loadRecommended() async { recommended = (try? await NetEaseAPI.shared.personalizedPlaylists(limit: 8)) ?? [] }
    private func loadNewSongs() async { newSongs = (try? await NetEaseAPI.shared.newSongs(limit: 10)) ?? [] }
    private func loadTopPlaylists() async { topPlaylists = (try? await NetEaseAPI.shared.topPlaylists(limit: 8)) ?? [] }

    private func playDaily() async {
        do {
            let songs = try await NetEaseAPI.shared.dailyRecommend()
            guard !songs.isEmpty else { toast = "今天还没有推荐，稍后再来"; return }
            player.play(songs: songs, startAt: 0)
        } catch { toast = error.localizedDescription }
    }

    private func playFM() async {
        do {
            let songs = try await NetEaseAPI.shared.personalFM()
            guard !songs.isEmpty else { toast = "私人 FM 暂无可播歌曲"; return }
            player.play(songs: songs, startAt: 0)
        } catch { toast = error.localizedDescription }
    }
}

// 轻量 toast
struct BeansToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text = message {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.beansCard, in: Capsule())
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation { self.message = nil }
                        }
                    }
            }
        }
    }
}

extension View {
    func beansToast(message: Binding<String?>) -> some View {
        modifier(BeansToastModifier(message: message))
    }
}