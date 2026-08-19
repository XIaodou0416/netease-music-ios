import Foundation

struct Song: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let artists: String
    let album: String
    let coverURL: URL?
    let duration: TimeInterval

    var formattedDuration: String {
        let total = max(0, Int(duration))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        name = json["name"] as? String ?? ""
        let artistsArray = json["artists"] as? [[String: Any]] ?? (json["ar"] as? [[String: Any]]) ?? []
        artists = artistsArray.compactMap { $0["name"] as? String }.joined(separator: " / ")
        if let albumDict = json["album"] as? [String: Any] {
            album = albumDict["name"] as? String ?? ""
            let pic = albumDict["picUrl"] as? String ?? (albumDict["blurPicUrl"] as? String ?? "")
            coverURL = pic.isEmpty ? nil : URL(string: pic)
        } else if let al = json["al"] as? [String: Any] {
            album = al["name"] as? String ?? ""
            let pic = al["picUrl"] as? String ?? ""
            coverURL = pic.isEmpty ? nil : URL(string: pic)
        } else {
            album = ""
            coverURL = nil
        }
        let ms = json["duration"] as? Int ?? (json["dt"] as? Int) ?? 0
        duration = Double(ms) / 1000.0
    }
}

struct Playlist: Identifiable, Hashable {
    let id: Int
    let name: String
    let coverURL: URL?
    let trackCount: Int
    let creatorName: String

    init(id: Int, name: String, coverURL: URL?, trackCount: Int = 0) {
        self.id = id
        self.name = name
        self.coverURL = coverURL
        self.trackCount = trackCount
        self.creatorName = ""
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        name = json["name"] as? String ?? ""
        trackCount = json["trackCount"] as? Int ?? 0
        let pic = json["coverImgUrl"] as? String ?? ""
        coverURL = pic.isEmpty ? nil : URL(string: pic)
        creatorName = (json["creator"] as? [String: Any])?["nickname"] as? String ?? ""
    }

    init?(personalizedJSON json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        name = json["name"] as? String ?? ""
        trackCount = 0
        let pic = json["picUrl"] as? String ?? ""
        coverURL = pic.isEmpty ? nil : URL(string: pic)
        creatorName = ""
    }
}

struct TopList: Identifiable, Hashable {
    let id: Int
    let name: String
    let coverURL: URL?
    let updateFrequency: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        name = json["name"] as? String ?? ""
        let pic = json["coverImgUrl"] as? String ?? ""
        coverURL = pic.isEmpty ? nil : URL(string: pic)
        updateFrequency = json["updateFrequency"] as? String ?? ""
    }
}

struct LyricLine: Identifiable, Hashable {
    let id: UUID
    let time: Double
    let text: String

    init(time: Double, text: String) {
        self.id = UUID()
        self.time = time
        self.text = text
    }
}

enum LyricParser {
    static func parse(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for line in raw.components(separatedBy: .newlines) {
            parseTimes(in: line).forEach { time in
                let text = line.replacingOccurrences(of: #"\[\d{2}:\d{2}(\.\d{1,3})?\]"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append(LyricLine(time: time, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private static func parseTimes(in line: String) -> [Double] {
        var times: [Double] = []
        let pattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(line.startIndex..., in: line)
        regex?.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
            guard let match else { return }
            guard let minuteRange = Range(match.range(at: 1), in: line),
                  let secondRange = Range(match.range(at: 2), in: line) else { return }
            let minutes = Double(line[minuteRange]) ?? 0
            let seconds = Double(line[secondRange]) ?? 0
            var fraction = 0.0
            if match.numberOfRanges > 3, let fracRange = Range(match.range(at: 3), in: line) {
                let raw = String(line[fracRange])
                fraction = (Double(raw) ?? 0) / pow(10, Double(max(raw.count, 1)))
            }
            times.append(minutes * 60 + seconds + fraction)
        }
        return times
    }
}

struct NetEaseUser: Identifiable, Hashable, Codable {
    let uid: Int
    let nickname: String
    let avatarURL: URL?

    var id: Int { uid }

    init?(json: [String: Any]) {
        guard let id = json["userId"] as? Int ?? (json["id"] as? Int) else { return nil }
        uid = id
        nickname = json["nickname"] as? String ?? ""
        let pic = json["avatarUrl"] as? String ?? ""
        avatarURL = pic.isEmpty ? nil : URL(string: pic)
    }
}