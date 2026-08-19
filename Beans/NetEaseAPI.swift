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

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
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
        guard http.statusCode == 200 else { throw NetEaseError.httpStatus(http.statusCode) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetEaseError.decoding
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

    // MARK: - 登录（eapi 二维码新流程）

    func qrKey() async throws -> String {
        let json = try await request("/api/login/qrcode/unikey", payload: ["type": 3], crypto: "eapi")
        if let key = json["unikey"] as? String, !key.isEmpty { return key }
        if let data = json["data"] as? [String: Any], let key = data["unikey"] as? String, !key.isEmpty { return key }
        throw NetEaseError.unknown("获取二维码密钥失败")
    }

    func qrLoginURL(key: String) -> String {
        "https://music.163.com/login?codekey=\(key)"
    }

    func qrCheck(key: String) async throws -> Int {
        let json = try await request("/api/login/qrcode/client/login", payload: ["key": key, "type": 3], crypto: "eapi")
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
}

enum NetEaseError: LocalizedError {
    case network
    case httpStatus(Int)
    case decoding
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network: return "网络连接失败，请检查网络"
        case .httpStatus(let code): return "服务器响应异常（\(code)）"
        case .decoding: return "数据解析失败"
        case .unknown(let message): return message
        }
    }
}