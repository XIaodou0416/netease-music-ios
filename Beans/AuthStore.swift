import Foundation

final class AuthStore: ObservableObject {
    @Published var user: NetEaseUser?
    @Published var isLoggedIn = false
    @Published var playlists: [Playlist] = []
    @Published var favoritePlaylistID: Int?
    @Published var favoriteTracks: [Song] = []
    /// 网易云「我喜欢的音乐」同步数量（likelist 接口）
    @Published var likedCount = 0

    private let defaults = UserDefaults.standard
    private let userKey = "beans.user"

    /// 界面展示的收藏数量：优先用云端同步数，缺失时退回本地列表数
    var displayedFavoriteCount: Int {
        likedCount > 0 ? likedCount : favoriteTracks.count
    }

    init() {
        if let data = defaults.data(forKey: userKey),
           let saved = try? JSONDecoder().decode(NetEaseUser.self, from: data) {
            user = saved
            isLoggedIn = true
        }
    }

    @MainActor
    func finishLogin() async throws {
        var account: NetEaseUser?
        for attempt in 0..<3 {
            do {
                account = try await NetEaseAPI.shared.account()
                break
            } catch {
                if attempt == 2 { throw error }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
        guard let account else { throw NetEaseError.unknown("获取账号信息失败") }
        let playlists = (try? await NetEaseAPI.shared.userPlaylists(uid: account.uid)) ?? []
        let favorite = playlists.first { $0.name == "我喜欢的音乐" }
        var tracks: [Song]
        if let favorite {
            tracks = (try? await NetEaseAPI.shared.playlistTracks(id: favorite.id)) ?? []
        } else {
            tracks = []
        }
        // 同步云端收藏数量；歌单未找到或为空时，用收藏列表兜底
        if let liked = try? await NetEaseAPI.shared.likedSongIDs(uid: account.uid) {
            likedCount = liked.count
            if tracks.isEmpty {
                let ids = Array(liked.ids.prefix(200))
                tracks = (try? await NetEaseAPI.shared.songDetails(ids: ids)) ?? []
            }
        } else {
            likedCount = tracks.count
        }
        user = account
        self.playlists = playlists
        favoritePlaylistID = favorite?.id
        favoriteTracks = tracks
        isLoggedIn = true
        if let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: userKey)
        }
    }

    @MainActor
    func loadLibrary() async {
        guard let user else { return }
        if let cached = try? await NetEaseAPI.shared.userPlaylists(uid: user.uid) {
            playlists = cached
            let favorite = cached.first { $0.name == "我喜欢的音乐" }
            favoritePlaylistID = favorite?.id
            if let favorite {
                favoriteTracks = (try? await NetEaseAPI.shared.playlistTracks(id: favorite.id)) ?? favoriteTracks
            }
            // 同步收藏数量
            if let liked = try? await NetEaseAPI.shared.likedSongIDs(uid: user.uid) {
                likedCount = liked.count
                if favorite == nil && favoriteTracks.isEmpty {
                    let ids = Array(liked.ids.prefix(200))
                    favoriteTracks = (try? await NetEaseAPI.shared.songDetails(ids: ids)) ?? favoriteTracks
                }
            } else {
                likedCount = favoriteTracks.count
            }
        }
    }

    /// 收藏/取消收藏：成功后同步更新「我喜欢的音乐」列表与计数
    @MainActor
    func toggleLike(_ song: Song) async throws -> Bool {
        let isLiked = favoriteTracks.contains { $0.id == song.id }
        let ok = try await NetEaseAPI.shared.like(id: song.id, liked: !isLiked)
        guard ok else { return false }
        if isLiked {
            favoriteTracks.removeAll { $0.id == song.id }
            likedCount = max(0, likedCount - 1)
        } else {
            favoriteTracks.insert(song, at: 0)
            likedCount += 1
        }
        // 与云端收藏总数对齐（后台执行，不阻塞 UI）
        Task { @MainActor in
            if let uid = user?.uid,
               let liked = try? await NetEaseAPI.shared.likedSongIDs(uid: uid) {
                likedCount = liked.count
            }
        }
        return true
    }

    /// 某首歌当前是否为已收藏状态（按 id 判断，避免不同来源同一首歌因字段差异误判）
    func isLiked(_ song: Song) -> Bool {
        favoriteTracks.contains { $0.id == song.id }
    }

    func logout() {
        NetEaseAPI.shared.clearCookies()
        user = nil
        playlists = []
        favoritePlaylistID = nil
        favoriteTracks = []
        likedCount = 0
        isLoggedIn = false
        defaults.removeObject(forKey: userKey)
    }
}