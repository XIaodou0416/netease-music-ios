import Foundation

final class NetEaseAPI {
    static let shared = NetEaseAPI()

    private let domain = "https://music.163.com"
    private let apiDomain = "https://interface.music.163.com"
    private let session: URLSession

    // 模拟 PC 客户端环境（与 NeteaseCloudMusicApi 一致）
    private let os = "pc"
    private let appver = "3.1.17.204416"
    private let osver = "Microsoft-Windows-10-Professional-build-19045-64bit"
    private let channel = "netease"

    private let nuid: String
    private let deviceId: String
    private let wnMcid: String
    private var storedCookies: [String: String] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)

        nuid = Self.randomHex(length: 32)      // 64 位 hex
        deviceId = Self.randomHex(length: 26)  // 52 位 hex
        wnMcid = "\(Self.randomLowercase(6)).\(Int(Date().timeIntervalSince1970 * 1000)).01.0"
    }

    // MARK: - 请求

    private func request(_ uri: String, payload: [String: Any], crypto: String) async throws -> [String: Any] {
        let url: URL
        let form: String
        var request: URLRequest

        if crypto == "weapi" {
            url = URL(string: domain + "/weapi" + uri.dropFirst(4))!
            var data = payload
            data["csrf_token"] = csrfToken
            let enc = NetEaseCrypto.weapi(data)
            form = "params=\(formEncode(enc["params"] ?? ""))&encSecKey=\(formEncode(enc["encSecKey"] ?? ""))"
            request = URLRequest(url: url)
            request.setValue(weapiCookieHeader(), forHTTPHeaderField: "Cookie")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0", forHTTPHeaderField: "User-Agent")
            request.setValue(domain, forHTTPHeaderField: "Referer")
        } else {
            url = URL(string: apiDomain + "/eapi" + uri.dropFirst(4))!
            let header = eapiHeader()
            var data = payload
            data["e_r"] = false
            data["header"] = header
            let enc = NetEaseCrypto.eapi(data, path: uri)
            form = "params=\(formEncode(enc["params"] ?? ""))"
            request = URLRequest(url: url)
            request.setValue(eapiCookieHeader(header: header), forHTTPHeaderField: "Cookie")
            request.setValue("NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)", forHTTPHeaderField: "User-Agent")
        }

        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(form.utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetEaseError.network }
        storeCookies(from: http)
        guard http.statusCode == 200 else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw NetEaseError.httpStatus(http.statusCode, String(snippet))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw NetEaseError.decoding(String(snippet))
        }
        return json
    }

    private func formEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    // MARK: - Cookie 构造

    private var csrfToken: String {
        cookieValue(named: "__csrf")
    }

    private var musicU: String {
        cookieValue(named: "MUSIC_U")
    }

    private func cookieValue(named name: String) -> String {
        (HTTPCookieStorage.shared.cookies ?? []).first { $0.name == name }?.value ?? ""
    }

    func clearCookies() {
        storedCookies.removeAll()
    }

    private func storeCookies(from response: HTTPURLResponse) {
        guard let header = response.value(forHTTPHeaderField: "Set-Cookie") else { return }
        for part in header.components(separatedBy: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            let name = kv[0].trimmingCharacters(in: .whitespaces)
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
            guard name.rangeOfCharacter(from: allowed.inverted) == nil, !value.isEmpty else { continue }
            storedCookies[name] = value
        }
    }

    private func weapiCookieHeader() -> String {
        let ts = String(Int(Date().timeIntervalSince1970 * 1000))
        var parts: [String] = []
        parts.append("__remember_me=true")
        parts.append("ntes_kaola_ad=1")
        parts.append("_ntes_nuid=\(nuid)")
        parts.append("_ntes_nnid=\(nuid),\(ts)")
        parts.append("WNMCID=\(wnMcid)")
        parts.append("WEVNSM=1.0.0")
        parts.append("osver=\(osver)")
        parts.append("deviceId=\(deviceId)")
        parts.append("os=\(os)")
        parts.append("channel=\(channel)")
        parts.append("appver=\(appver)")
        parts.append("NMTID=\(Self.randomHex(length: 16))")
        if !musicU.isEmpty { parts.append("MUSIC_U=\(musicU)") }
        if !csrfToken.isEmpty { parts.append("__csrf=\(csrfToken)") }
        return parts.joined(separator: "; ")
    }

    private func eapiHeader() -> [String: String] {
        let ts = String(Int(Date().timeIntervalSince1970 * 1000))
        let buildver = String(ts.prefix(10))
        var header: [String: String] = [
            "osver": osver,
            "deviceId": deviceId,
            "os": os,
            "appver": appver,
            "versioncode": "140",
            "mobilename": "",
            "buildver": buildver,
            "resolution": "1920x1080",
            "__csrf": csrfToken,
            "channel": channel,
            "requestId": "\(ts)_\(String(format: "%04d", Int.random(in: 0...999)))",
        ]
        if !musicU.isEmpty { header["MUSIC_U"] = musicU }
        return header
    }

    private func eapiCookieHeader(header: [String: String]) -> String {
        header.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "; ")
    }

    private static func randomHex(length: Int) -> String {
        let chars = "0123456789abcdef"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func randomLowercase(_ count: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<count).compactMap { _ in chars.randomElement() })
    }

    // MARK: - 登录（二维码，eapi 优先、weapi 降级）

    func qrKey() async throws -> String {
        do {
            return try await qrKeyEAPI()
        } catch {
            return try await qrKeyWEAPI()
        }
    }

    private func qrKeyEAPI() async throws -> String {
        let json = try await request("/api/login/qrcode/unikey", payload: ["type": 3], crypto: "eapi")
        if let key = json["unikey"] as? String, !key.isEmpty { return key }
        if let data = json["data"] as? [String: Any], let key = data["unikey"] as? String, !key.isEmpty { return key }
        throw NetEaseError.unknown("获取二维码密钥失败")
    }

    private func qrKeyWEAPI() async throws -> String {
        let json = try await request("/api/login/qrcode/unikey", payload: ["type": 3], crypto: "weapi")
        if let key = json["unikey"] as? String, !key.isEmpty { return key }
        if let data = json["data"] as? [String: Any], let key = data["unikey"] as? String, !key.isEmpty { return key }
        throw NetEaseError.unknown("获取二维码密钥失败")
    }

    func qrLoginURL(key: String) -> String {
        "https://music.163.com/login?codekey=\(key)"
    }

    func qrCheck(key: String) async throws -> Int {
        do {
            let json = try await request("/api/login/qrcode/client/login", payload: ["key": key, "type": 3], crypto: "eapi")
            let code = json["code"] as? Int ?? -1
            if code != -1 { return code }
        } catch {}
        let json = try await request("/api/login/qrcode/client/login", payload: ["key": key, "type": 3], crypto: "weapi")
        return json["code"] as? Int ?? -1
    }

    func account() async throws -> NetEaseUser {
        let json = try await request("/api/w/nuser/account/get", payload: [:], crypto: "weapi")
        guard let profile = json["profile"] as? [String: Any], let user = NetEaseUser(json: profile) else {
            throw NetEaseError.unknown("获取账号信息失败")
        }
        return user
    }

    // MARK: - 音乐库

    func userPlaylists(uid: Int) async throws -> [Playlist] {
        let json = try await request("/api/user/playlist", payload: ["uid": uid, "limit": 1000, "offset": 0, "includeVideo": true], crypto: "weapi")
        let list = json["playlist"] as? [[String: Any]] ?? []
        return list.compactMap(Playlist.init(json:))
    }

    func playlistTracks(id: Int) async throws -> [Song] {
        let json = try await request("/api/v6/playlist/detail", payload: ["id": id, "n": 100000, "s": 8], crypto: "eapi")
        let playlist = json["playlist"] as? [String: Any] ?? [:]
        let tracks = playlist["tracks"] as? [[String: Any]] ?? []
        return tracks.compactMap(Song.init(json:))
    }

    func songURLs(ids: [Int], level: String = "standard") async throws -> [Int: String] {
        let idsString = "[" + ids.map(String.init).joined(separator: ",") + "]"
        let json = try await request("/api/song/enhance/player/url/v1", payload: ["ids": idsString, "level": level, "encodeType": "flac"], crypto: "eapi")
        let data = json["data"] as? [[String: Any]] ?? []
        var result: [Int: String] = [:]
        for item in data {
            if let id = item["id"] as? Int, let url = item["url"] as? String, !url.isEmpty {
                result[id] = url
            }
        }
        return result
    }

    // MARK: - 歌词

    func lyric(id: Int) async throws -> String? {
        let json = try await request("/api/song/lyric", payload: ["id": id, "lv": -1, "kv": -1, "tv": -1], crypto: "weapi")
        guard let lrc = json["lrc"] as? [String: Any], let text = lrc["lyric"] as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    // MARK: - 搜索

    func search(keyword: String, limit: Int = 30, offset: Int = 0) async throws -> [Song] {
        let json = try await request("/api/cloudsearch/pc", payload: ["s": keyword, "type": 1, "limit": limit, "offset": offset, "total": true], crypto: "weapi")
        let result = json["result"] as? [String: Any] ?? [:]
        let songs = result["songs"] as? [[String: Any]] ?? []
        return songs.compactMap(Song.init(json:))
    }

    // MARK: - 收藏

    func like(id: Int, liked: Bool) async throws -> Bool {
        let json = try await request("/api/song/like", payload: ["like": liked, "id": id], crypto: "weapi")
        return (json["code"] as? Int) == 200
    }

    // MARK: - 发现

    func topLists() async throws -> [TopList] {
        let json = try await request("/api/toplist/detail", payload: [:], crypto: "weapi")
        let list = json["list"] as? [[String: Any]] ?? []
        return list.prefix(12).compactMap(TopList.init(json:))
    }

    func dailyRecommend() async throws -> [Song] {
        let json = try await request("/api/v3/discovery/recommend/songs", payload: [:], crypto: "weapi")
        let data = json["data"] as? [String: Any] ?? [:]
        let songs = data["dailySongs"] as? [[String: Any]] ?? []
        return songs.compactMap(Song.init(json:))
    }

    func personalizedPlaylists(limit: Int = 20) async throws -> [Playlist] {
        let json = try await request("/api/personalized/playlist", payload: ["limit": limit, "n": limit], crypto: "weapi")
        let list = json["result"] as? [[String: Any]] ?? []
        return list.compactMap(Playlist.init(personalizedJSON:))
    }

    // MARK: - 更多发现

    func hotSearch() async throws -> [String] {
        let json = try await request("/api/search/hot", payload: ["type": 1111], crypto: "weapi")
        let hots = json["result"] as? [String: Any] ?? [:]
        let list = hots["hots"] as? [[String: Any]] ?? []
        return list.compactMap { $0["first"] as? String }.prefix(10).map { $0 }
    }

    func newSongs(limit: Int = 10) async throws -> [Song] {
        let json = try await request("/api/personalized/newsong", payload: ["type": 0, "limit": limit], crypto: "weapi")
        let list = json["result"] as? [[String: Any]] ?? []
        var songs: [Song] = []
        for item in list {
            if let songJSON = item["song"] as? [String: Any], let song = Song(json: songJSON) {
                songs.append(song)
            } else if let song = Song(json: item) {
                songs.append(song)
            }
        }
        return songs
    }

    func topPlaylists(limit: Int = 10) async throws -> [Playlist] {
        let json = try await request("/api/top/playlist", payload: ["limit": limit, "order": "hot", "cat": "全部", "total": true], crypto: "weapi")
        let list = json["playlists"] as? [[String: Any]] ?? []
        return list.compactMap(Playlist.init(json:))
    }

    func simiSongs(id: Int) async throws -> [Song] {
        let json = try await request("/api/simi/song", payload: ["songid": id], crypto: "weapi")
        let list = json["songs"] as? [[String: Any]] ?? []
        return list.compactMap(Song.init(json:))
    }

    func personalFM() async throws -> [Song] {
        let json = try await request("/api/v1/radio/get", payload: [:], crypto: "weapi")
        let list = json["data"] as? [[String: Any]] ?? []
        return list.compactMap(Song.init(json:))
    }

    // MARK: - 歌单编辑

    func createPlaylist(name: String) async throws -> Int {
        let json = try await request("/api/playlist/create", payload: ["name": name, "privacy": 0], crypto: "weapi")
        guard let id = json["id"] as? Int else {
            throw NetEaseError.unknown("创建歌单失败")
        }
        return id
    }

    func addToPlaylist(playlistID: Int, songIDs: [Int]) async throws -> Bool {
        let tracks = "[" + songIDs.map(String.init).joined(separator: ",") + "]"
        let json = try await request("/api/playlist/manipulate/tracks", payload: ["op": "add", "pid": playlistID, "tracks": tracks], crypto: "weapi")
        return (json["code"] as? Int) == 200
    }
}

enum NetEaseError: LocalizedError {
    case network
    case httpStatus(Int, String)
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network: return "网络连接失败，请检查网络"
        case .httpStatus(let code, let snippet):
            return snippet.isEmpty ? "服务器响应异常（\(code)）" : "服务器响应异常（\(code)）\(snippet)"
        case .decoding(let snippet):
            return snippet.isEmpty ? "数据解析失败" : "数据解析失败：\(snippet)"
        case .unknown(let message): return message
        }
    }
}