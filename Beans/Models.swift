import Foundation

struct Song: Identifiable, Hashable {
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

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        name = json["name"] as? String ?? ""
        trackCount = json["trackCount"] as? Int ?? 0
        let pic = json["coverImgUrl"] as? String ?? ""
        coverURL = pic.isEmpty ? nil : URL(string: pic)
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