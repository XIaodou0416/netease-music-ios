import AVFoundation
import MediaPlayer
import SwiftUI

enum PlayMode: String, CaseIterable, Identifiable {
    case sequential
    case repeatOne
    case shuffle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sequential: return "repeat"
        case .repeatOne: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }

    var title: String {
        switch self {
        case .sequential: return "顺序播放"
        case .repeatOne: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }
}

final class PlayerManager: NSObject, ObservableObject {
    @Published var queue: [Song] = []
    @Published var currentIndex = 0
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var playMode: PlayMode = .sequential
    @Published var rate: Double = 1.0
    @Published var sleepTimerEndsAt: Date?
    @Published var sleepTimerRemaining: Int = 0
    @Published var history: [Song] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var sessionConfigured = false
    private var playOrder: [Int] = []
    private var orderPosition = 0
    private var sleepTimer: Timer?

    private let historyKey = "beans.history"
    private let defaults = UserDefaults.standard

    var currentSong: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    var currentQueueIndex: Int {
        orderPosition
    }

    override init() {
        super.init()
        loadHistory()
        setupRemoteCommands()
    }

    // MARK: - 播放控制

    func play(songs: [Song], startAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        queue = songs
        buildPlayOrder()
        jumpToOrderPosition(min(max(index, 0), songs.count - 1))
    }

    func playSong(_ song: Song, in context: [Song]) {
        play(songs: context, startAt: context.firstIndex(of: song) ?? 0)
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.playImmediately(atRate: Float(rate))
            isPlaying = true
        }
        updateNowPlaying()
    }

    func next(manual: Bool = true) {
        guard !queue.isEmpty else { return }
        if playMode == .repeatOne && manual {
            restartCurrent()
            return
        }
        advance()
        loadCurrent()
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if progress > 3 {
            seek(to: 0)
            return
        }
        if playMode == .shuffle {
            orderPosition = (orderPosition - 1 + playOrder.count) % playOrder.count
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        loadCurrent()
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, max(duration, 0)))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        progress = clamped
        updateNowPlaying()
    }

    func togglePlayMode() {
        switch playMode {
        case .sequential: playMode = .repeatOne
        case .repeatOne: playMode = .shuffle
        case .shuffle: playMode = .sequential
        }
        buildPlayOrder()
    }

    func setRate(_ newRate: Double) {
        rate = newRate
        if isPlaying {
            player?.playImmediately(atRate: Float(newRate))
        }
        updateNowPlaying()
    }

    func playQueueIndex(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        jumpToOrderPosition(index)
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), queue.count > 1 else { return }
        let removedID = queue[index].id
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            currentIndex = min(currentIndex, queue.count - 1)
            loadCurrent()
        }
        buildPlayOrder(avoiding: removedID)
    }

    // MARK: - 睡眠定时

    func startSleepTimer(minutes: Int) {
        stopSleepTimer()
        sleepTimerEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerRemaining = minutes * 60
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let end = self.sleepTimerEndsAt else { return }
            let remain = Int(end.timeIntervalSinceNow)
            self.sleepTimerRemaining = max(0, remain)
            if remain <= 0 {
                self.stopSleepTimer()
                self.pausePlayback()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndsAt = nil
        sleepTimerRemaining = 0
    }

    var sleepTimerFormatted: String? {
        guard sleepTimerRemaining > 0 else { return nil }
        return String(format: "%d:%02d", sleepTimerRemaining / 60, sleepTimerRemaining % 60)
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    // MARK: - 播放顺序

    private func buildPlayOrder(avoiding removedID: Int? = nil) {
        switch playMode {
        case .shuffle:
            var indices = Array(queue.indices).filter { $0 != removedID }
            indices.shuffle()
            playOrder = indices
            orderPosition = 0
        default:
            playOrder = Array(queue.indices)
            orderPosition = currentIndex
        }
    }

    private func advance() {
        switch playMode {
        case .shuffle:
            orderPosition = (orderPosition + 1) % playOrder.count
            currentIndex = playOrder[orderPosition]
        default:
            currentIndex = (currentIndex + 1) % queue.count
            orderPosition = currentIndex
        }
    }

    private func jumpToOrderPosition(_ index: Int) {
        currentIndex = index
        if playMode == .shuffle {
            orderPosition = 0
            if let pos = playOrder.firstIndex(of: index) {
                orderPosition = pos
            }
        } else {
            orderPosition = index
        }
        loadCurrent()
    }

    // MARK: - 播放

    private func restartCurrent() {
        seek(to: 0)
        player?.playImmediately(atRate: Float(rate))
        isPlaying = true
        updateNowPlaying()
    }

    private func loadCurrent() {
        guard let song = currentSong else { return }
        duration = song.duration
        progress = 0
        isPlaying = false
        isBuffering = true
        pushHistory(song)
        Task {
            let urls = try? await NetEaseAPI.shared.songURLs(ids: [song.id])
            guard let urlString = urls?[song.id], let url = URL(string: urlString) else {
                await MainActor.run {
                    self.isBuffering = false
                    self.autoSkipOnFailure()
                }
                return
            }
            await MainActor.run { self.setupPlayer(url: url) }
        }
    }

    private func autoSkipOnFailure() {
        if queue.count > 1 {
            advance()
            loadCurrent()
        }
    }

    private func setupPlayer(url: URL) {
        configureAudioSession()
        removeCurrentObservers()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.rate = Float(rate)
        self.player = player
        player.playImmediately(atRate: Float(rate))
        isPlaying = true
        isBuffering = false
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, let player = self.player else { return }
            self.progress = player.currentTime().seconds
            if let itemDuration = player.currentItem?.duration, itemDuration.isNumeric {
                self.duration = itemDuration.seconds
            }
            if let item = player.currentItem {
                let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                if waiting != self.isBuffering {
                    self.isBuffering = waiting
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.playMode == .repeatOne {
                self.restartCurrent()
            } else {
                self.advance()
                self.loadCurrent()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.autoSkipOnFailure()
        }
        updateNowPlaying()
    }

    private func removeCurrentObservers() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
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

    // MARK: - 播放历史

    private func pushHistory(_ song: Song) {
        history.removeAll { $0.id == song.id }
        history.insert(song, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return }
        history = saved
    }

    // MARK: - 锁屏/控制中心

    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artists,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: max(duration, song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
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
            self?.player?.playImmediately(atRate: Float(self?.rate ?? 1.0))
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
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
}