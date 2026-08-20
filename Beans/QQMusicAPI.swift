import Foundation

/// QQ 音乐搜索类型
enum QQSearchType: Int {
    case song = 0
    case artist = 2
    case album = 3
}

/// QQ 音乐接口（搜索 / 播放地址 / 歌词 / 热搜）
/// 说明：搜索与 vkey 接口对数据中心 IP 会返回空结果（服务器端过滤），
/// 在用户手机（家庭/移动网络）下正常工作；歌词与热搜接口已验证可用。
final class QQMusicAPI {
    static let shared = QQMusicAPI()

    private let base = "https://u.y.qq.com/cgi-bin/musicu.fcg"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    // MARK: - 基础请求

    private func get(_ urlString: String, referer: String = "https://y.qq.com/") async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw NetEaseError.unknown("请求地址无效") }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 QQMusic/9.0.5", forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("uin=0; qqmusic_fromtag=66", forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetEaseError.network
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw NetEaseError.decoding(String(snippet))
        }
        return json
    }

    private func musicu(_ payload: [String: Any]) async throws -> [String: Any] {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let raw = String(data: data, encoding: .utf8),
              let encoded = raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw NetEaseError.unknown("请求参数错误")
        }
        return try await get("\(base)?format=json&data=\(encoded)")
    }

    private static func photoURL(_ mid: String?, size: String = "300x300") -> URL? {
        guard let mid, !mid.isEmpty else { return nil }
        return URL(string: "https://y.gtimg.cn/music/photo_new/T002R\(size)M000\(mid).jpg")
    }

    // MARK: - 搜索

    /// 搜索歌曲（QQ 音乐）
    func searchSongs(keyword: String, limit: Int = 30) async throws -> [Song] {
        let payload: [String: Any] = [
            "comm": ["ct": 24, "cv": 0, "uin": "0", "format": "json"],
            "req_1": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": ["query": keyword, "num_per_page": limit, "page_num": 1, "search_type": QQSearchType.song.rawValue],
            ],
        ]
        let json = try await musicu(payload)
        let list = nestedArray(json, path: ["req_1", "data", "body", "song", "list"])
        var songs: [Song] = []
        for item in list {
            guard let id = item["id"] as? Int, let mid = item["mid"] as? String else { continue }
            let singer = (item["singer"] as? [[String: Any]]) ?? []
            let artists = singer.compactMap { $0["name"] as? String }.joined(separator: " / ")
            let albumDict = item["album"] as? [String: Any]
            let albumName = albumDict?["name"] as? String ?? ""
            let albumMid = albumDict?["mid"] as? String
            let interval = (item["interval"] as? Int) ?? 0
            songs.append(Song(
                id: id,
                name: item["name"] as? String ?? "",
                artists: artists,
                album: albumName,
                coverURL: Self.photoURL(albumMid),
                duration: TimeInterval(interval),
                source: .qq,
                qqMid: mid
            ))
        }
        return songs
    }

    /// 搜索歌手（QQ 音乐）
    func searchArtists(keyword: String, limit: Int = 30) async throws -> [Artist] {
        let payload: [String: Any] = [
            "comm": ["ct": 24, "cv": 0, "uin": "0", "format": "json"],
            "req_1": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": ["query": keyword, "num_per_page": limit, "page_num": 1, "search_type": QQSearchType.artist.rawValue],
            ],
        ]
        let json = try await musicu(payload)
        let list = nestedArray(json, path: ["req_1", "data", "body", "singer", "list"])
        var artists: [Artist] = []
        for item in list {
            let name = item["name"] as? String ?? (item["title"] as? String ?? "")
            guard !name.isEmpty else { continue }
            let mid = item["mid"] as? String
            let numericID = item["id"] as? Int ?? 0
            artists.append(Artist(
                id: mid ?? "qq-\(numericID)-\(name)",
                name: name,
                coverURL: Self.photoURL(mid),
                source: .qq
            ))
        }
        return artists
    }

    /// 搜索专辑（QQ 音乐）
    func searchAlbums(keyword: String, limit: Int = 30) async throws -> [Album] {
        let payload: [String: Any] = [
            "comm": ["ct": 24, "cv": 0, "uin": "0", "format": "json"],
            "req_1": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": ["query": keyword, "num_per_page": limit, "page_num": 1, "search_type": QQSearchType.album.rawValue],
            ],
        ]
        let json = try await musicu(payload)
        let list = nestedArray(json, path: ["req_1", "data", "body", "album", "list"])
        var albums: [Album] = []
        for item in list {
            let name = item["name"] as? String ?? (item["title"] as? String ?? "")
            guard !name.isEmpty else { continue }
            let mid = item["mid"] as? String
            let singer = (item["singer"] as? [[String: Any]]) ?? []
            let artistName = singer.compactMap { $0["name"] as? String }.joined(separator: " / ")
            let numericID = item["id"] as? Int ?? 0
            albums.append(Album(
                id: mid ?? "qq-\(numericID)-\(name)",
                name: name,
                artistName: artistName,
                coverURL: Self.photoURL(mid),
                source: .qq,
                trackCount: item["total"] as? Int
            ))
        }
        return albums
    }

    /// QQ 音乐热搜词
    func hotKeys(limit: Int = 10) async throws -> [String] {
        let url = "https://c.y.qq.com/splcloud/fcgi-bin/gethotkey.fcg?format=json&inCharset=utf8&outCharset=utf-8"
        let json = try await get(url)
        let data = json["data"] as? [String: Any] ?? [:]
        let hots = data["hotkey"] as? [[String: Any]] ?? []
        return hots.compactMap { $0["k"] as? String }.prefix(limit).map { $0 }
    }

    // MARK: - 播放 / 歌词

    /// 通过 vkey 获取 QQ 音乐播放地址（免费歌曲返回可播 URL，VIP 歌曲返回 nil）
    func songURL(songmid: String) async throws -> String? {
        let payload: [String: Any] = [
            "req": [
                "module": "vkey.GetVkeyServer",
                "method": "CgiGetVkey",
                "param": [
                    "guid": "\(Int.random(in: 10000...99999999))",
                    "songmid": [songmid],
                    "songtype": [0],
                    "uin": "0",
                    "loginflag": 1,
                    "platform": "20",
                ],
            ],
        ]
        let json = try await musicu(payload)
        guard let req = json["req"] as? [String: Any],
              let data = req["data"] as? [String: Any],
              let sips = data["sip"] as? [String],
              let infos = data["midurlinfo"] as? [[String: Any]],
              let info = infos.first,
              let purl = info["purl"] as? String, !purl.isEmpty else { return nil }
        if purl.hasPrefix("http") { return purl }
        let base = sips.first ?? "https://aqqmusic.tc.qq.com/"
        return base + purl
    }

    /// QQ 音乐歌词（LRC 文本）
    func lyric(songmid: String) async throws -> String? {
        guard let mid = songmid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let url = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(mid)&format=json&nobase64=1&g_tk=5381"
        let json = try await get(url, referer: "https://y.qq.com/portal/player.html")
        guard let lyric = json["lyric"] as? String, !lyric.isEmpty else { return nil }
        return lyric
    }

    // MARK: - 工具

    private func nestedArray(_ json: [String: Any], path: [String]) -> [[String: Any]] {
        var current: Any = json
        for key in path {
            if let dict = current as? [String: Any] {
                current = dict[key] ?? [:]
            } else {
                return []
            }
        }
        return (current as? [[String: Any]]) ?? []
    }
}