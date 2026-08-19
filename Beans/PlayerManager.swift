import AVFoundation
import MediaPlayer
import SwiftUI

final class PlayerManager: NSObject, ObservableObject {
    @Published var queue: [Song] = []
    @Published var currentIndex = 0
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var sessionConfigured = false

    var currentSong: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    override init() {
        super.init()
        setupRemoteCommands()
    }

    // MARK: - 控制

    func play(songs: [Song], startAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        queue = songs
        currentIndex = min(max(index, 0), songs.count - 1)
        loadCurrent()
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        loadCurrent()
    }

    func previous() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        loadCurrent()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    // MARK: - 播放

    private func loadCurrent() {
        guard let song = currentSong else { return }
        duration = song.duration
        progress = 0
        isPlaying = false
        Task {
            let urls = try? await NetEaseAPI.shared.songURLs(ids: [song.id])
            guard let urlString = urls?[song.id], let url = URL(string: urlString) else { return }
            await MainActor.run { self.setupPlayer(url: url) }
        }
    }

    private func setupPlayer(url: URL) {
        configureAudioSession()
        removeCurrentObserver()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.play()
        isPlaying = true
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, let player = self.player else { return }
            self.progress = player.currentTime().seconds
            if let itemDuration = player.currentItem?.duration, itemDuration.isNumeric {
                self.duration = itemDuration.seconds
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)
        updateNowPlaying()
    }

    @objc private func itemDidEnd() {
        next()
    }

    private func removeCurrentObserver() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func configureAudioSession() {
        guard !sessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            sessionConfigured = true
        } catch {}
    }

    // MARK: - 锁屏控制

    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artists,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        if let artworkURL = song.coverURL {
            Task {
                if let data = try? Data(contentsOf: artworkURL), let image = UIImage(data: data) {
                    var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            self?.updateNowPlaying()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlaying()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }
}