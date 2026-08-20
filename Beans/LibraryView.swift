import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @Binding var tab: BeansTab
    @State private var selectedPlaylist: Playlist?
    @State private var loaded = false
    @State private var topLists: [TopList] = []
    @State private var recommended: [Playlist] = []
    @State private var newSongs: [Song] = []
    @State private var topPlaylists: [Playlist] = []
    @State private var dailySongs: [Song] = []
    @State private var showSearch = false
    @State private var toast: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if auth.isLoggedIn {
                        if auth.playlists.isEmpty && !loaded {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            favoriteCard
                            playlistSection
                        }
                    } else {
                        loginPromptCard
                    }
                    discoverSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .beansPageBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BeansBottomBar(selected: $tab)
            }
            .refreshable {
                await refreshAll()
            }
            .navigationDestination(item: $selectedPlaylist) { playlist in
                PlaylistView(playlist: playlist)
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .task {
                await refreshAll()
                loaded = true
            }
        }
        .beansToast(message: $toast)
    }

    private func refreshAll() async {
        async let tops: Void = loadTopLists()
        async let recs: Void = loadRecommended()
        async let news: Void = loadNewSongs()
        async let tops2: Void = loadTopPlaylists()
        _ = await (tops, recs, news, tops2)
        if auth.isLoggedIn {
            await auth.loadLibrary()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("音乐库")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.beansLabel)
                if let user = auth.user {
                    Text(user.nickname)
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                } else {
                    Text("发现好歌，登录同步收藏")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }
            }
            Spacer()
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
    }

    // MARK: - 登录提示（未登录）

    private var loginPromptCard: some View {
        Button {
            tab = .profile
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 50, height: 50)
                    .background(Color.beansAmber.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录同步你的收藏")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                    Text("扫码登录网易云，歌单和「我喜欢的音乐」都会出现在这里")
                        .font(.caption)
                        .foregroundStyle(Color.beansSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(Color.beansSecondary)
            }
        }
        .buttonStyle(.plain)
        .beansGlassCard(cornerRadius: 20)
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
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("我喜欢的音乐").font(.headline).foregroundStyle(Color.beansLabel)
                    Text("\(auth.favoriteTracks.count) 首 · 点按播放")
                        .font(.caption)
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.beansAmber)
            }
        }
        .buttonStyle(.plain)
        .beansGlassCard(cornerRadius: 20)
    }

    // MARK: - 我的歌单

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("我的歌单").font(.title2.bold()).foregroundStyle(Color.beansLabel)
                Spacer()
                Button {
                    Task { await createPlaylist() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: columns, spacing: 18) {
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
                            Text("\(playlist.trackCount) 首")
                                .font(.caption2)
                                .foregroundStyle(Color.beansSecondary)
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

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("发现").font(.title2.bold()).foregroundStyle(Color.beansLabel)

            if topLists.isEmpty && newSongs.isEmpty && recommended.isEmpty && topPlaylists.isEmpty {
                BeansEmptyState(icon: "music.note", title: "发现内容加载失败", subtitle: "请下拉刷新或检查网络")
                    .frame(minHeight: 220)
            }

            if auth.isLoggedIn {
                HStack(spacing: 12) {
                    dailyCard
                    privateFMButton
                }
            }

            if !topLists.isEmpty {
                sectionHeader("排行榜")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(topLists) { top in
                            Button {
                                selectedPlaylist = Playlist(id: top.id, name: top.name, coverURL: top.coverURL)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    BeansCover(url: top.coverURL)
                                        .frame(width: 112, height: 112)
                                    Text(top.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(top.updateFrequency)
                                        .font(.caption2)
                                        .foregroundStyle(Color.beansSecondary)
                                        .lineLimit(1)
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
                sectionHeader("新歌速递")
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
                                            Image(systemName: "play.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.beansAmber)
                                                .padding(5)
                                        }
                                    Text(song.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(song.artists)
                                        .font(.caption2)
                                        .foregroundStyle(Color.beansSecondary)
                                        .lineLimit(1)
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
                sectionHeader("推荐歌单")
                LazyVGrid(columns: columns, spacing: 18) {
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
                sectionHeader("精品歌单")
                LazyVGrid(columns: columns, spacing: 18) {
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
                                Text("\(playlist.trackCount) 首")
                                    .font(.caption2)
                                    .foregroundStyle(Color.beansSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(Color.beansLabel)
    }

    // MARK: - 每日推荐 / 私人FM（大玻璃卡片）

    private var dailyCard: some View {
        Button {
            Task { await playDaily() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("每日推荐").font(.subheadline.weight(.semibold)).foregroundStyle(Color.beansLabel)
                    Text("30 首").font(.caption2).foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 4)
            }
        }
        .buttonStyle(.plain)
        .beansGlassCard(cornerRadius: 18, padding: 12)
    }

    private var privateFMButton: some View {
        Button {
            Task { await playFM() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "radio")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("私人 FM").font(.subheadline.weight(.semibold)).foregroundStyle(Color.beansLabel)
                    Text("猜你喜欢").font(.caption2).foregroundStyle(Color.beansSecondary)
                }
                Spacer(minLength: 4)
            }
        }
        .buttonStyle(.plain)
        .beansGlassCard(cornerRadius: 18, padding: 12)
    }

    private func playDaily() async {
        do {
            dailySongs = try await NetEaseAPI.shared.dailyRecommend()
            guard !dailySongs.isEmpty else {
                toast = "今天还没有推荐，稍后再来"
                return
            }
            player.play(songs: dailySongs, startAt: 0)
        } catch {
            toast = error.localizedDescription
        }
    }

    private func playFM() async {
        do {
            let fmSongs = try await NetEaseAPI.shared.personalFM()
            guard !fmSongs.isEmpty else {
                toast = "私人 FM 暂无可播歌曲"
                return
            }
            player.play(songs: fmSongs, startAt: 0)
        } catch {
            toast = error.localizedDescription
        }
    }

    private func loadTopLists() async {
        topLists = (try? await NetEaseAPI.shared.topLists()) ?? []
    }

    private func loadRecommended() async {
        recommended = (try? await NetEaseAPI.shared.personalizedPlaylists(limit: 8)) ?? []
    }

    private func loadNewSongs() async {
        newSongs = (try? await NetEaseAPI.shared.newSongs(limit: 10)) ?? []
    }

    private func loadTopPlaylists() async {
        topPlaylists = (try? await NetEaseAPI.shared.topPlaylists(limit: 8)) ?? []
    }
}

// 轻量 toast 提示
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
                    .background(Color.beansGlassFill)
                    .glassEffect(.regular)
                    .clipShape(Capsule())
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