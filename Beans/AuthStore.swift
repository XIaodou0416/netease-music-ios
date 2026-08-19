import Foundation

final class AuthStore: ObservableObject {
    @Published var user: NetEaseUser?
    @Published var isLoggedIn = false
    @Published var playlists: [Playlist] = []
    @Published var favoritePlaylistID: Int?
    @Published var favoriteTracks: [Song] = []

    private let defaults = UserDefaults.standard
    private let userKey = "beans.user"

    init() {
        if let data = defaults.data(forKey: userKey),
           let saved = try? JSONDecoder().decode(NetEaseUser.self, from: data) {
            user = saved
            isLoggedIn = true
        }
    }

    @MainActor
    func finishLogin() async throws {
        let account = try await NetEaseAPI.shared.account()
        let playlists = (try? await NetEaseAPI.shared.userPlaylists(uid: account.uid)) ?? []
        let favorite = playlists.first { $0.name == "我喜欢的音乐" }
        let tracks: [Song]
        if let favorite {
            tracks = (try? await NetEaseAPI.shared.playlistTracks(id: favorite.id)) ?? []
        } else {
            tracks = []
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
        }
    }

    func logout() {
        NetEaseAPI.shared.clearCookies()
        user = nil
        playlists = []
        favoritePlaylistID = nil
        favoriteTracks = []
        isLoggedIn = false
        defaults.removeObject(forKey: userKey)
    }
}