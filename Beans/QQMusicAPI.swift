import Foundation

/// QQ 音乐搜索类型（musicu search_type：0 单曲 / 1 歌手 / 2 专辑 / 3 歌单 / 4 MV / 7 歌词 / 8 用户）
enum QQSearchType: Int {
    case song = 0
    case artist = 1
    case album = 2
}

/// QQ 音乐接口（搜索 / 播放地址 / 歌词 / 热搜）
/// 参考 wp_MusicApi（https://github.com/GitHub-ZC/wp_MusicApi）逆向结论：
/// - 歌曲搜索改用 client_search_cp（t=0），该接口对家庭/移动/数据中心网络均可用；
///   歌手/专辑搜索使用 musicu.fcg POST JSON（search_type 1/2），专辑空结果时自动用 client_search_cp t=8 兜底。
/// - vkey 播放地址经 musicu.fcg 获取，VIP 歌曲返回空；部分数据中心 IP 会被风控返回空，家庭网络正常。
final class QQMusicAPI {
    static let shared = QQMusicAPI()

    private let base = "https://u.y.qq.com/cgi-bin/musicu.fcg"
    private let searchBase = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp"
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
        guard let json = parseJSON(data) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw NetEaseError.decoding(String(snippet))
        }
        return json
    }

    /// musicu.fcg 统一入口：POST JSON body（与 wp_MusicApi 一致）
    private func musicu(_ payload: [String: Any]) async throws -> [String: Any] {
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let url = URL(string: base) else {
            throw NetEaseError.unknown("请求参数错误")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetEaseError.network
        }
        guard let json = parseJSON(data) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw NetEaseError.decoding(String(snippet))
        }
        return json
    }

    /// 兼容纯 JSON 与 JSONP（`callback({...})`）两种响应
    private func parseJSON(_ data: Data) -> [String: Any]? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        guard let text = String(data: data, encoding: .utf8),
              let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let slice = text[start...end]
        guard let obj = try? JSONSerialization.jsonObject(with: Data(slice.utf8)) as? [String: Any] else { return nil }
        return obj
    }

    private static func photoURL(_ mid: String?, size: String = "300x300") -> URL? {
        guard let mid, !mid.isEmpty else { return nil }
        return URL(string: "https://y.gtimg.cn/music/photo_new/T002R\(size)M000\(mid).jpg")
    }

    private func musicuSearchPayload(keyword: String, limit: Int, type: QQSearchType) -> [String: Any] {
        [
            "comm": ["ct": 19, "cv": 1859, "uin": "0", "format": "json"],
            "req_1": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": [
                    "query": keyword,
                    "num_per_page": limit,
                    "page_num": 1,
                    "search_type": type.rawValue,
                    "grp": 1,
                ],
            ],
        ]
    }

    /// client_search_cp 搜索 URL（t：0 单曲 / 8 专辑 / 9 歌手）
    private func clientSearchURL(keyword: String, limit: Int, type: Int) -> URL? {
        var comps = URLComponents(string: searchBase)
        comps?.queryItems = [
            URLQueryItem(name: "ct", value: "24"),
            URLQueryItem(name: "qqmusic_ver", value: "1298"),
            URLQueryItem(name: "remoteplace", value: "txt.yqq.top"),
            URLQueryItem(name: "aggr", value: "1"),
            URLQueryItem(name: "cr", value: "1"),
            URLQueryItem(name: "catZhida", value: "1"),
            URLQueryItem(name: "lossless", value: "0"),
            URLQueryItem(name: "flag_qc", value: "0"),
            URLQueryItem(name: "t", value: "\(type)"),
            URLQueryItem(name: "p", value: "1"),
            URLQueryItem(name: "n", value: "\(limit)"),
            URLQueryItem(name: "w", value: keyword),
            URLQueryItem(name: "cv", value: "4747474"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "inCharset", value: "utf-8"),
            URLQueryItem(name: "outCharset", value: "utf-8"),
            URLQueryItem(name: "notice", value: "0"),
            URLQueryItem(name: "platform", value: "yqq.json"),
            URLQueryItem(name: "needNewCode", value: "0"),
            URLQueryItem(name: "uin", value: "0"),
            URLQueryItem(name: "hostUin", value: "0"),
            URLQueryItem(name: "loginUin", value: "0"),
        ]
        return comps?.url
    }

    // MARK: - 搜索

    /// 搜索歌曲（client_search_cp，本机与手机网络均可）
    func searchSongs(keyword: String, limit: Int = 30) async throws -> [Song] {
        guard let url = clientSearchURL(keyword: keyword, limit: limit, type: 0) else {
            throw NetEaseError.unknown("搜索地址无效")
        }
        let json = try await get(url.absoluteString, referer: "https://y.qq.com/portal/player.html")
        let data = json["data"] as? [String: Any] ?? [:]
        let song = data["song"] as? [String: Any] ?? [:]
        let list = song["list"] as? [[String: Any]] ?? []
        var songs: [Song] = []
        for item in list {
            guard let songid = item["songid"] as? Int, let mid = item["songmid"] as? String else { continue }
            let singer = (item["singer"] as? [[String: Any]]) ?? []
            let artists = singer.compactMap { $0["name"] as? String }.joined(separator: " / ")
            let albumMid = item["albummid"] as? String
            let interval = (item["interval"] as? Int) ?? 0
            songs.append(Song(
                id: songid,
                name: item["songname"] as? String ?? "",
                artists: artists,
                album: item["albumname"] as? String ?? "",
                coverURL: Self.photoURL(albumMid),
                duration: TimeInterval(interval),
                source: .qq,
                qqMid: mid
            ))
        }
        return songs
    }

    /// 搜索歌手（musicu search_type=1，本机实测可用）
    func searchArtists(keyword: String, limit: Int = 30) async throws -> [Artist] {
        let json = try await musicu(musicuSearchPayload(keyword: keyword, limit: limit, type: .artist))
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

    /// 搜索专辑（musicu search_type=2 为主；空结果时用 client_search_cp t=8 兜底）
    func searchAlbums(keyword: String, limit: Int = 30) async throws -> [Album] {
        let json = try await musicu(musicuSearchPayload(keyword: keyword, limit: limit, type: .album))
        let list = nestedArray(json, path: ["req_1", "data", "body", "album", "list"])
        if !list.isEmpty {
            return parseAlbumItems(list)
        }
        // 兜底：client_search_cp t=8
        if let url = clientSearchURL(keyword: keyword, limit: limit, type: 8) {
            let fallback = try? await get(url.absoluteString, referer: "https://y.qq.com/portal/player.html")
            let data = fallback?["data"] as? [String: Any] ?? [:]
            let album = data["album"] as? [String: Any] ?? [:]
            let fallbackList = album["list"] as? [[String: Any]] ?? []
            if !fallbackList.isEmpty {
                return parseAlbumItems(fallbackList)
            }
        }
        return []
    }

    private func parseAlbumItems(_ items: [[String: Any]]) -> [Album] {
        var albums: [Album] = []
        for item in items {
            let name = item["name"] as? String ?? (item["albumname"] as? String ?? "")
            guard !name.isEmpty else { continue }
            let mid = item["mid"] as? String ?? (item["albummid"] as? String)
            let singer = (item["singer"] as? [[String: Any]]) ?? []
            let artistName = singer.compactMap { $0["name"] as? String }.joined(separator: " / ")
            let numericID = item["id"] as? Int ?? 0
            albums.append(Album(
                id: mid ?? "qq-album-\(numericID)-\(name)",
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
            "comm": ["uin": 0, "format": "json", "ct": 24, "cv": 0],
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
              let infos = data["midurlinfo"] as? [[String: Any]],
              let info = infos.first,
              let purl = info["purl"] as? String, !purl.isEmpty else { return nil }
        if purl.hasPrefix("http") { return purl }
        return "https://isure.stream.qqmusic.qq.com/" + purl
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