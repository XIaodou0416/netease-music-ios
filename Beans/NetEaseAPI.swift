import Foundation

final class NetEaseAPI {
    static let shared = NetEaseAPI()

    private let baseURL = "https://music.163.com"
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 NeteaseMusic/9.5.0"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    // MARK: - 请求

    private func post(path: String, payload: [String: Any], crypto: String = "weapi") async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String]
        if crypto == "eapi" {
            body = NetEaseCrypto.eapi(payload, path: path.replacingOccurrences(of: "/eapi", with: "/api"))
        } else {
            body = NetEaseCrypto.weapi(payload)
        }
        let form = body.map { "\($0.key)=\(formEncode($0.value))" }.joined(separator: "&")
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

    private var timestamp: Int { Int(Date().timeIntervalSince1970 * 1000) }

    // MARK: - 登录

    func qrKey() async throws -> String {
        let json = try await post(path: "/weapi/login/qr/key", payload: ["type": 1, "key": "", "timestamp": timestamp])
        guard let data = json["data"] as? [String: Any], let key = data["unikey"] as? String, !key.isEmpty else {
            throw NetEaseError.unknown("获取二维码密钥失败")
        }
        return key
    }

    func qrCreate(key: String) async throws -> (url: String, imageBase64: String) {
        let json = try await post(path: "/weapi/login/qr/create", payload: ["key": key, "qrimg": true, "timestamp": timestamp])
        guard let data = json["data"] as? [String: Any] else {
            throw NetEaseError.unknown("生成二维码失败")
        }
        return (data["url"] as? String ?? "", data["qrimg"] as? String ?? "")
    }

    func qrCheck(key: String) async throws -> Int {
        let json = try await post(path: "/weapi/login/qr/check", payload: ["key": key, "timestamp": timestamp])
        return json["code"] as? Int ?? -1
    }

    func account() async throws -> NetEaseUser {
        let json = try await post(path: "/weapi/w/nuser/account/get", payload: ["csrf_token": ""])
        guard let profile = json["profile"] as? [String: Any], let user = NetEaseUser(json: profile) else {
            throw NetEaseError.unknown("获取账号信息失败")
        }
        return user
    }

    // MARK: - 音乐库

    func userPlaylists(uid: Int) async throws -> [Playlist] {
        let json = try await post(path: "/weapi/user/playlist", payload: ["uid": uid, "limit": 1000, "offset": 0, "includeVideo": true, "csrf_token": ""])
        let list = json["playlist"] as? [[String: Any]] ?? []
        return list.compactMap(Playlist.init(json:))
    }

    func playlistTracks(id: Int) async throws -> [Song] {
        let json = try await post(path: "/weapi/v6/playlist/detail", payload: ["id": id, "n": 100000, "s": 8, "csrf_token": ""])
        let playlist = json["playlist"] as? [String: Any] ?? [:]
        let tracks = playlist["tracks"] as? [[String: Any]] ?? []
        return tracks.compactMap(Song.init(json:))
    }

    func songURLs(ids: [Int], level: String = "standard") async throws -> [Int: String] {
        let idsString = "[" + ids.map(String.init).joined(separator: ",") + "]"
        let json = try await post(path: "/weapi/song/enhance/player/url/v1", payload: ["ids": idsString, "level": level, "csrf_token": ""])
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