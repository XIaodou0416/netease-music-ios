import Foundation

// MARK: - 下载音质

enum DownloadQuality: String, CaseIterable, Identifiable {
    case high
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: return "高质量（320kbps）"
        case .low: return "低质量（128kbps）"
        }
    }

    /// 网易云音质档位（player/url v1 level）
    var neteaseLevel: String {
        switch self {
        case .high: return "exhigh"
        case .low: return "standard"
        }
    }

    /// QQ 音乐音质档位（M800=320k / M500=128k）
    var qqBR: String {
        switch self {
        case .high: return "M800"
        case .low: return "M500"
        }
    }
}

// MARK: - 歌曲下载

/// 下载歌曲到 Documents/BeansDownloads（已开启文件共享，可在系统「文件」App 中访问）
@MainActor
final class DownloadManager {
    static let shared = DownloadManager()

    private init() {}

    @discardableResult
    func download(song: Song, quality: DownloadQuality) async -> Result<URL, Error> {
        // 1) 解析播放地址（与播放共用同一套接口，仅指定音质）
        let urlString: String?
        if song.source == .qq, let mid = song.qqMid {
            urlString = try? await QQMusicAPI.shared.songURL(songmid: mid, br: quality.qqBR)
        } else {
            let urls = try? await NetEaseAPI.shared.songURLs(ids: [song.id], level: quality.neteaseLevel)
            urlString = urls?[song.id]
        }
        guard let urlString, let url = URL(string: urlString), !urlString.isEmpty else {
            return .failure(NetEaseError.unknown("无法解析播放地址（可能是 VIP 歌曲）"))
        }

        // 2) 下载到临时文件
        let tempURL: URL
        do {
            let (downloaded, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .failure(NetEaseError.unknown("下载失败（HTTP \(http.statusCode)）"))
            }
            tempURL = downloaded
        } catch {
            return .failure(NetEaseError.unknown("下载失败：\(error.localizedDescription)"))
        }

        // 3) 移动到 BeansDownloads 目录（文件名包含歌曲与歌手，已存在的覆盖）
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeansDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeName = "\(song.name) - \(song.artists)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let ext = song.source == .qq ? "m4a" : "mp3"
        let dest = dir.appendingPathComponent("\(safeName).\(ext)")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: tempURL, to: dest)
        } catch {
            return .failure(NetEaseError.unknown("保存失败：\(error.localizedDescription)"))
        }
        return .success(dest)
    }
}
