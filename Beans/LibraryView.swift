import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @Binding var tab: BeansTab
    @State private var selectedPlaylist: Playlist?
    @State private var loaded = false
    @State private var topLists: [TopList] = []
    @State private var recommended: [Playlist] = []
    @State private var dailySongs: [Song] = []
    @State private var showSearch = false
    @State private var toast: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
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
                .padding(.bottom, 110)
            }
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationDestination(item: $selectedPlaylist) { playlist in
                PlaylistView(playlist: playlist)
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchView()
            }
            .task {
                async let tops: Void = loadTopLists()
                async let recs: Void = loadRecommended()
                _ = await (tops, recs)
                if auth.isLoggedIn {
                    await auth.loadLibrary()
                }
                loaded = true
            }
        }
        .beansToast(message: $toast)
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

    // MARK: - 登录提示

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
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(Color.beansSecondary)
            }
            .padding(16)
            .background(Color.beansCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.beansAmber)
            }
            .padding(14)
            .background(Color.beansCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(auth.playlists.filter { $0.id != auth.favoritePlaylistID }) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            cover(playlist.coverURL)
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
            let id = try await NetEaseAPI.shared.createPlaylist(name: name)
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

            if auth.isLoggedIn {
                Button {
                    Task { await playDaily() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("每日推荐").font(.headline).foregroundStyle(Color.beansLabel)
                            Text("根据你的口味，每天更新 30 首").font(.caption).foregroundStyle(Color.beansSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(Color.beansLabel)
                            .frame(width: 32, height: 32)
                            .background(Color.beansAmber, in: Circle())
                    }
                    .padding(14)
                    .background(Color.beansCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !topLists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("排行榜").font(.headline).foregroundStyle(Color.beansLabel)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(topLists) { top in
                                Button {
                                    selectedPlaylist = Playlist(id: top.id, name: top.name, coverURL: top.coverURL)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        cover(top.coverURL)
                                            .frame(width: 108, height: 108)
                                        Text(top.name)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text(top.updateFrequency)
                                            .font(.caption2)
                                            .foregroundStyle(Color.beansSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 108)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !recommended.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("推荐歌单").font(.headline).foregroundStyle(Color.beansLabel)
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(recommended) { playlist in
                            Button {
                                selectedPlaylist = playlist
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    cover(playlist.coverURL)
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
            }
        }
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

    private func loadTopLists() async {
        topLists = (try? await NetEaseAPI.shared.topLists()) ?? []
    }

    private func loadRecommended() async {
        recommended = (try? await NetEaseAPI.shared.personalizedPlaylists(limit: 8)) ?? []
    }

    private func cover(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(Color.beansCard)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// 轻量 toast 提示
struct BeansToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 90)
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