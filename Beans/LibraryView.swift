import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @Binding var tab: BeansTab
    @State private var selectedPlaylist: Playlist?
    @State private var loaded = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !auth.isLoggedIn {
                        loginPromptCard
                    } else if auth.playlists.isEmpty && !loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else if auth.playlists.isEmpty {
                        emptyHint
                    } else {
                        favoriteCard
                        playlistGrid
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationDestination(item: $selectedPlaylist) { playlist in
                PlaylistView(playlist: playlist)
            }
            .task {
                guard !loaded else { return }
                await auth.loadLibrary()
                loaded = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Beans")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color.beansCream)
            Text("一杯好歌，来自你的网易云")
                .font(.footnote)
                .foregroundStyle(Color.beansMuted)
            if let user = auth.user {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Color.beansAmber)
                    Text(user.nickname)
                        .font(.subheadline)
                        .foregroundStyle(Color.beansCream.opacity(0.8))
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 10)
    }

    private var loginPromptCard: some View {
        Button {
            tab = .profile
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 52, height: 52)
                    .background(Color.beansAmber.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录后同步你的收藏")
                        .font(.headline)
                        .foregroundStyle(Color.beansCream)
                    Text("扫码登录网易云，歌单和「我喜欢的音乐」都会出现在这里")
                        .font(.caption)
                        .foregroundStyle(Color.beansMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(Color.beansMuted)
            }
            .padding(16)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(Color.beansMuted)
            Text("还没有加载到歌单，下拉重试")
                .font(.footnote)
                .foregroundStyle(Color.beansMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var favoriteCard: some View {
        Button {
            if !auth.favoriteTracks.isEmpty {
                player.play(songs: auth.favoriteTracks, startAt: 0)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("我喜欢的音乐").font(.headline).foregroundStyle(Color.beansCream)
                    Text("\(auth.favoriteTracks.count) 首 · 点按播放")
                        .font(.caption)
                        .foregroundStyle(Color.beansMuted)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.beansAmber)
            }
            .padding(14)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var playlistGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的歌单").font(.title2.bold()).foregroundStyle(Color.beansCream)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(auth.playlists.filter { $0.id != auth.favoritePlaylistID }) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            cover(playlist)
                            Text(playlist.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.beansCream)
                                .lineLimit(2, reservesSpace: true)
                                .multilineTextAlignment(.leading)
                            Text("\(playlist.trackCount) 首")
                                .font(.caption2)
                                .foregroundStyle(Color.beansMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cover(_ playlist: Playlist) -> some View {
        AsyncImage(url: playlist.coverURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(.white.opacity(0.07))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}