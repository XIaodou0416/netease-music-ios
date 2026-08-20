import Foundation

/// QQ 音乐扫码登录（逆向自 wp_MusicApi util/login_qq_scan.js，仅供学习交流）
/// 流程：ptqrshow 生成二维码 -> ptqrlogin 轮询扫码状态 -> check_sig 拿 skey/p_skey
///      -> graph.qq.com oauth2 authorize 换 code -> musicu.fcg QQConnectLogin 换 musickey
/// 登录后播放请求携带 qq.com 域 Cookie（p_skey / qqmusic_key），QQ 歌曲播放成功率显著提升。
final class QQMusicAuth: ObservableObject {
    static let shared = QQMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var nickname = ""

    private var cookies: [String: String] = [:]
    private var qrsig = ""

    private let defaults = UserDefaults.standard
    private let cookieKey = "beans.qqmusic.cookie.v1"
    private let nickKey = "beans.qqmusic.nickname.v1"
    private let session: URLSession
    private let redirectBlocker = NoRedirectDelegate()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        session = URLSession(configuration: config, delegate: redirectBlocker, delegateQueue: nil)
        if let saved = defaults.dictionary(forKey: cookieKey) as? [String: String], !saved.isEmpty {
            cookies = saved
            isLoggedIn = true
            nickname = defaults.string(forKey: nickKey) ?? ""
        }
    }

    // MARK: - 登录状态

    /// 登录 QQ 号（cookie uin 形如 o153140965）
    var uin: String {
        let raw = cookies["uin"] ?? "0"
        return raw.replacingOccurrences(of: "o", with: "")
    }

    /// 播放接口 loginKey（优先 p_skey，其次 qqmusic_key / musickey）
    var loginKey: String {
        cookies["p_skey"] ?? cookies["qqmusic_key"] ?? cookies["musickey"] ?? ""
    }

    /// 发给 u.y.qq.com 的 Cookie 串（含 qqmusic_key 时 VIP 歌曲播放成功率最高）
    var cookieHeader: String {
        let order = ["uin", "p_skey", "skey", "qqmusic_key", "musickey", "pt4_token", "qm_keyst"]
        return order.compactMap { key in
            guard let value = cookies[key], !value.isEmpty else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: "; ")
    }

    func logout() {
        cookies = [:]
        qrsig = ""
        isLoggedIn = false
        nickname = ""
        defaults.removeObject(forKey: cookieKey)
        defaults.removeObject(forKey: nickKey)
    }

    // MARK: - 扫码登录

    enum ScanState: Equatable {
        case waiting
        case scanned
        case success(String)   // 昵称
        case expired
        case error(String)
    }

    /// 获取二维码图片（PNG），并保存 qrsig 供轮询使用
    func fetchQRCode() async throws -> Data {
        qrsig = ""
        var comps = URLComponents(string: "https://ssl.ptlogin2.qq.com/ptqrshow")!
        comps.queryItems = [
            URLQueryItem(name: "appid", value: "716027609"),
            URLQueryItem(name: "e", value: "2"),
            URLQueryItem(name: "l", value: "M"),
            URLQueryItem(name: "s", value: "3"),
            URLQueryItem(name: "d", value: "72"),
            URLQueryItem(name: "v", value: "4"),
            URLQueryItem(name: "t", value: String(format: "%.6f", Double.random(in: 0...1))),
            URLQueryItem(name: "daid", value: "383"),
            URLQueryItem(name: "pt_3rd_aid", value: "100497308"),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        request.setValue("https://xui.ptlogin2.qq.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        collectCookies(from: response)
        guard let qr = cookies["qrsig"], !qr.isEmpty else {
            throw NetEaseError.unknown("获取 QQ 二维码失败，请检查网络后重试")
        }
        qrsig = qr
        return data
    }

    /// 单次轮询扫码状态（调用方以 3 秒间隔重复调用）
    func poll() async throws -> ScanState {
        guard !qrsig.isEmpty else { return .expired }
        var comps = URLComponents(string: "https://ssl.ptlogin2.qq.com/ptqrlogin")!
        comps.queryItems = [
            URLQueryItem(name: "u1", value: "https://graph.qq.com/oauth2.0/login_jump"),
            URLQueryItem(name: "ptqrtoken", value: "\(Self.hash33(qrsig))"),
            URLQueryItem(name: "ptredirect", value: "0"),
            URLQueryItem(name: "h", value: "1"),
            URLQueryItem(name: "t", value: "1"),
            URLQueryItem(name: "g", value: "1"),
            URLQueryItem(name: "from_ui", value: "1"),
            URLQueryItem(name: "ptlang", value: "2052"),
            URLQueryItem(name: "action", value: "0-0-\\(Int(Date().timeIntervalSince1970 * 1000))"),
            URLQueryItem(name: "js_ver", value: "22080914"),
            URLQueryItem(name: "js_type", value: "1"),
            URLQueryItem(name: "login_sig", value: ""),
            URLQueryItem(name: "pt_uistyle", value: "40"),
            URLQueryItem(name: "aid", value: "716027609"),
            URLQueryItem(name: "daid", value: "383"),
            URLQueryItem(name: "pt_3rd_aid", value: "100497308"),
            URLQueryItem(name: "o1vId", value: "49283d5cbb01a744d46314da4608d929"),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        request.setValue("https://xui.ptlogin2.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("qrsig=\(qrsig)", forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        collectCookies(from: response)
        guard let text = String(data: data, encoding: .utf8),
              let parsed = Self.parsePTUI(text) else {
            return .error("QQ 登录接口异常，请重试")
        }
        switch parsed.code {
        case "0":
            guard let url = parsed.url else { return .error("登录成功但凭证获取失败") }
            do {
                try await completeOAuth(redirectURL: url)
            } catch {
                return .error(error.localizedDescription)
            }
            nickname = parsed.nickname
            isLoggedIn = true
            defaults.set(cookies, forKey: cookieKey)
            defaults.set(nickname, forKey: nickKey)
            return .success(parsed.nickname)
        case "65", "68":
            return .expired
        case "67":
            return .scanned
        case "66":
            return .waiting
        default:
            return .waiting
        }
    }

    // MARK: - 授权换 musickey

    private func completeOAuth(redirectURL: String) async throws {
        // 1. 依次访问 check_sig 跳转链，收集 skey / p_skey（最多 6 跳）
        var current = redirectURL
        for _ in 0..<6 {
            guard let url = URL(string: current) else { break }
            var request = URLRequest(url: url)
            request.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
            request.setValue("https://xui.ptlogin2.qq.com/", forHTTPHeaderField: "Referer")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            let (_, response) = try await session.data(for: request)
            collectCookies(from: response)
            guard let http = response as? HTTPURLResponse,
                  (300...399).contains(http.statusCode),
                  let location = http.value(forHTTPHeaderField: "Location"),
                  !location.isEmpty else { break }
            current = location
        }

        // 2. graph.qq.com oauth2 authorize 换 code
        let gtk = Self.hash5381(cookies["qqmusic_key"] ?? cookies["p_skey"] ?? cookies["skey"] ?? "")
        let fields: [String: String] = [
            "response_type": "code",
            "client_id": "100497308",
            "redirect_uri": "https://y.qq.com/portal/wx_redirect.html?login_type=1&surl=https://y.qq.com/",
            "scope": "all",
            "state": "state",
            "switch": "",
            "from_ptlogin": "1",
            "src": "1",
            "update_auth": "1",
            "openapi": "80901010_1030",
            "g_tk": "\(gtk)",
            "auth_time": "\(Int(Date().timeIntervalSince1970 * 1000))",
            "ui": "DFEC5395-9E69-4D3E-96A6-300BB770874D",
        ]
        var authRequest = URLRequest(url: URL(string: "https://graph.qq.com/oauth2.0/authorize")!)
        authRequest.httpMethod = "POST"
        authRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        authRequest.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        authRequest.setValue("https://graph.qq.com/", forHTTPHeaderField: "Referer")
        authRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        authRequest.httpBody = Self.formEncode(fields).data(using: .utf8)
        let (_, authResponse) = try await session.data(for: authRequest)
        collectCookies(from: authResponse)
        guard let http = authResponse as? HTTPURLResponse,
              let location = http.value(forHTTPHeaderField: "Location"),
              let code = Self.extractCode(from: location) else {
            throw NetEaseError.unknown("QQ 授权失败，请重新扫码")
        }

        // 3. musicu.fcg QQConnectLogin 换 musickey（登录态 Cookie 持久化）
        let body = "{\"comm\":{\"g_tk\":5381,\"platform\":\"yqq\",\"ct\":24,\"cv\":0},\"req\":{\"module\":\"QQConnectLogin.LoginServer\",\"method\":\"QQLogin\",\"param\":{\"code\":\"\(code)\"}}}"
        var loginRequest = URLRequest(url: URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        loginRequest.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        loginRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        loginRequest.httpBody = body.data(using: .utf8)
        let (_, loginResponse) = try await session.data(for: loginRequest)
        collectCookies(from: loginResponse)
    }

    // MARK: - 工具

    private static let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    private func collectCookies(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse,
              let headers = http.allHeaderFields as? [String: String] else { return }
        let setCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: http.url!)
        for cookie in setCookies where !cookie.name.isEmpty {
            cookies[cookie.name] = cookie.value
        }
    }

    /// 解析 ptuiCB('66','','0','','') 形式的 JSONP 回调
    /// 兼容两种历史格式：code,url,'0',msg,nick 与 code,'0',url,msg,nick
    private static func parsePTUI(_ text: String) -> (code: String, url: String?, nickname: String)? {
        guard let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")") else { return nil }
        let inner = text[text.index(after: open)..<close]
        let parts = inner.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
        }
        guard parts.count >= 5 else { return nil }
        let url: String
        if parts[1].hasPrefix("http") {
            url = parts[1]
        } else {
            url = parts.count > 2 ? parts[2] : ""
        }
        return (parts[0], url.isEmpty ? nil : url, parts[4])
    }

    private static func extractCode(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value else { return nil }
        return code
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        fields.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    /// 对应 JS: e += (e << 5) + t.charCodeAt(n); return 2147483647 & e（e 初始 0）—— ptqrtoken 用
    static func hash33(_ t: String) -> Int {
        var e: Int64 = 0
        for unit in t.utf16 {
            let shifted = Int32(truncatingIfNeeded: e) &* 32
            e = Int64(shifted) + Int64(unit)
        }
        return Int(Int32(truncatingIfNeeded: e) & 0x7FFF_FFFF)
    }

    /// 对应 wp_MusicApi 的 f()：n 初始 5381，key 取 skey/qqmusic_key —— oauth g_tk 用
    static func hash5381(_ t: String) -> Int {
        var e: Int64 = 5381
        for unit in t.utf16 {
            let shifted = Int32(truncatingIfNeeded: e) &* 32
            e = Int64(shifted) + Int64(unit)
        }
        return Int(Int32(truncatingIfNeeded: e) & 0x7FFF_FFFF)
    }
}

/// 拦截自动重定向，手动处理 302（oauth authorize 需要从 Location 拿 code）
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
