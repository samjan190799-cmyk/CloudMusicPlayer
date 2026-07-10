import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Состояние воспроизведения
enum PlaybackState {
    case stopped
    case playing
    case paused
    case loading
}

/// Режим повтора треков
enum RepeatMode {
    case none
    case one
    case all
}

/// Модель единого трека для плеера (обобщает локальные и облачные треки)
struct PlayerTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let sourceName: String // "Медиатека", "Google Drive", "Яндекс Диск"
    let localURL: URL?
    let remoteURL: URL?
    let googleFileId: String? // Для получения авторизованного запроса
    
    static func == (lhs: PlayerTrack, rhs: PlayerTrack) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Менеджер воспроизведения аудио
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentTrack: PlayerTrack?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    @Published var isMuted = false {
        didSet {
            player?.isMuted = isMuted
        }
    }
    @Published var repeatMode: RepeatMode = .none
    @Published var isShuffleEnabled = false
    
    // Очередь треков
    @Published var playlist: [PlayerTrack] = []
    private var shuffledPlaylist: [PlayerTrack] = []
    private var currentTrackIndex: Int = -1
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var playerItemContext = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Настройка фонового аудио-сеанса
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Ошибка настройки AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Управление воспроизведением
    
    /// Воспроизведение конкретного трека
    func play(track: PlayerTrack, in queue: [PlayerTrack]) {
        self.playlist = queue
        if isShuffleEnabled {
            generateShuffledPlaylist(keeping: track)
        }
        
        self.currentTrack = track
        self.currentTrackIndex = getPlaylist().firstIndex(of: track) ?? -1
        
        loadAndPlay(track: track)
    }
    
    /// Воспроизведение / Пауза текущего трека
    func togglePlayPause() {
        guard let _ = currentTrack else { return }
        
        if playbackState == .playing {
            player?.pause()
            playbackState = .paused
            updateNowPlayingPlaybackState()
        } else if playbackState == .paused {
            player?.play()
            playbackState = .playing
            updateNowPlayingPlaybackState()
        }
    }
    
    /// Следующий трек
    func nextTrack() {
        let activePlaylist = getPlaylist()
        guard !activePlaylist.isEmpty else { return }
        
        var nextIndex = currentTrackIndex + 1
        if nextIndex >= activePlaylist.count {
            if repeatMode == .all {
                nextIndex = 0
            } else {
                return // Достигнут конец очереди
            }
        }
        
        currentTrackIndex = nextIndex
        let track = activePlaylist[nextIndex]
        self.currentTrack = track
        loadAndPlay(track: track)
    }
    
    /// Предыдущий трек
    func previousTrack() {
        let activePlaylist = getPlaylist()
        guard !activePlaylist.isEmpty else { return }
        
        // Если трек играет дольше 3 секунд, перематываем на начало
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        var prevIndex = currentTrackIndex - 1
        if prevIndex < 0 {
            if repeatMode == .all {
                prevIndex = activePlaylist.count - 1
            } else {
                seek(to: 0)
                return
            }
        }
        
        currentTrackIndex = prevIndex
        let track = activePlaylist[prevIndex]
        self.currentTrack = track
        loadAndPlay(track: track)
    }
    
    /// Перемотка на указанное время (в секундах)
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        playbackState = .loading
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                DispatchQueue.main.async {
                    self?.playbackState = self?.player?.rate == 0 ? .paused : .playing
                    self?.updateNowPlayingTime()
                }
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    private func getPlaylist() -> [PlayerTrack] {
        return isShuffleEnabled ? shuffledPlaylist : playlist
    }
    
    private func generateShuffledPlaylist(keeping track: PlayerTrack) {
        var temp = playlist.filter { $0.id != track.id }
        temp.shuffle()
        shuffledPlaylist = [track] + temp
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled, let current = currentTrack {
            generateShuffledPlaylist(keeping: current)
            currentTrackIndex = 0
        } else if let current = currentTrack {
            currentTrackIndex = playlist.firstIndex(of: current) ?? -1
        }
    }
    
    func toggleRepeatMode() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .none
        }
    }
    
    private func loadAndPlay(track: PlayerTrack) {
        playbackState = .loading
        currentTime = 0.0
        duration = 0.0
        
        // Сброс старого плеера
        player?.pause()
        removeTimeObserver()
        
        var playerItem: AVPlayerItem? = nil
        
        // 1. Офлайн файл из Медиатеки
        if let localURL = track.localURL, FileManager.default.fileExists(atPath: localURL.path) {
            playerItem = AVPlayerItem(url: localURL)
        }
        // 2. Локальный файл из Кэша (CacheManager)
        else if let cachedURL = CacheManager.shared.getCachedURL(for: track.id) {
            playerItem = AVPlayerItem(url: cachedURL)
        }
        // 3. Google Drive онлайн стриминг (требуется заголовок OAuth)
        else if let fileId = track.googleFileId, let token = GoogleDriveService.shared.getAccessToken() {
            let urlString = "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media"
            if let url = URL(string: urlString) {
                let headers = ["Authorization": "Bearer \(token)"]
                // AVURLAssetHTTPHeaderFieldsKey - недокументированный, но стабильный способ
                let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                playerItem = AVPlayerItem(asset: asset)
                
                // Запуск автоматического кэширования в фоне
                triggerCaching(for: track)
            }
        }
        // 4. Яндекс Диск онлайн стриминг (если предоставлен прямой URL)
        else if let remoteURL = track.remoteURL {
            playerItem = AVPlayerItem(url: remoteURL)
            // Запуск автоматического кэширования в фоне
            triggerCaching(for: track)
        }
        // 5. Запрос ссылки на ходу для Яндекса
        else if track.sourceName.contains("Яндекс") || track.sourceName == "Yandex" {
            // Запрашиваем URL скачивания перед воспроизведением
            YandexDiskService.shared.getDownloadUrl(forPath: track.id) { [weak self] downloadUrl in
                guard let downloadUrl = downloadUrl else {
                    DispatchQueue.main.async {
                        self?.playbackState = .stopped
                    }
                    return
                }
                DispatchQueue.main.async {
                    let item = AVPlayerItem(url: downloadUrl)
                    self?.setupPlayer(with: item, track: track)
                    
                    // Запуск автоматического кэширования в фоне
                    self?.triggerCaching(for: track)
                }
            }
            return
        }
        // 6. Стриминг с YouTube (получение ссылки на ходу через YouTubeKit)
        else if track.sourceName.contains("YouTube") {
            print("AudioPlayer: запрос аудио URL для YouTube трека: \(track.id) — \(track.title)")
            YouTubeService.shared.getAudioURL(for: track.id) { [weak self] audioUrl in
                if let audioUrl = audioUrl {
                    print("AudioPlayer: получен аудио URL: \(audioUrl.absoluteString.prefix(100))...")
                    
                    let headers = [
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                        "Referer": "https://www.youtube.com/"
                    ]
                    let asset = AVURLAsset(url: audioUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    let item = AVPlayerItem(asset: asset)
                    
                    self?.setupPlayer(with: item, track: track)
                    
                    // Запуск автоматического кэширования в фоне
                    self?.triggerCaching(for: track)
                } else {
                    print("AudioPlayer: ОШИБКА — не удалось получить аудио URL для YouTube трека \(track.id)")
                    self?.playbackState = .stopped
                }
            }
            return
        }
        
        guard let item = playerItem else {
            playbackState = .stopped
            return
        }
        
        setupPlayer(with: item, track: track)
    }
    
    /// Запуск кэширования трека в фоне
    private func triggerCaching(for track: PlayerTrack) {
        if track.googleFileId != nil {
            if let driveTrack = GoogleDriveService.shared.tracks.first(where: { $0.id == track.id }) {
                CacheManager.shared.cacheTrack(
                    trackId: track.id,
                    title: track.title,
                    source: .google,
                    size: driveTrack.sizeInBytes,
                    googleFileId: track.googleFileId,
                    yandexPath: nil
                )
            }
        } else if track.sourceName.contains("YouTube") {
            CacheManager.shared.cacheTrack(
                trackId: track.id,
                title: track.title,
                source: .youtube,
                size: 0,
                googleFileId: nil,
                yandexPath: nil
            )
        } else {
            // Для Яндекса ищем трек в списке
            if let yandexTrack = YandexDiskService.shared.tracks.first(where: { $0.id == track.id }) {
                CacheManager.shared.cacheTrack(
                    trackId: track.id,
                    title: track.title,
                    source: .yandex,
                    size: yandexTrack.size ?? 0,
                    googleFileId: nil,
                    yandexPath: yandexTrack.path
                )
            } else {
                // Запасной вариант, если трек не найден в общем списке
                CacheManager.shared.cacheTrack(
                    trackId: track.id,
                    title: track.title,
                    source: .yandex,
                    size: 0,
                    googleFileId: nil,
                    yandexPath: track.id
                )
            }
        }
    }
    
    private func setupPlayer(with item: AVPlayerItem, track: PlayerTrack) {
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.isMuted = isMuted
        
        // Наблюдатели за окончанием трека и изменением статуса
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        // Наблюдение за длительностью трека
        item.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    let seconds = CMTimeGetSeconds(item.duration)
                    if !seconds.isNaN {
                        self?.duration = seconds
                        self?.updateNowPlayingInfo(for: track)
                    }
                    self?.playbackState = .playing
                    self?.player?.play()
                } else if status == .failed {
                    self?.playbackState = .stopped
                    print("Ошибка воспроизведения элемента: \(String(describing: item.error))")
                }
            }
            .store(in: &cancellables)
        
        // Обсервация текущего времени проигрывания
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN {
                self?.currentTime = seconds
            }
        }
        
        updateNowPlayingInfo(for: track)
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        if repeatMode == .one {
            seek(to: 0)
            player?.play()
            playbackState = .playing
        } else {
            nextTrack()
        }
    }
    
    // MARK: - Системный экран блокировки (MPNowPlayingInfoCenter)
    
    private func updateNowPlayingInfo(for track: PlayerTrack) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.sourceName
        ]
        
        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        // Плейсхолдер обложки (красивый градиентный круг на черном фоне)
        if let image = drawPlaceholderImage(title: track.title) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackState() {
        let rate = playbackState == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    }
    
    private func updateNowPlayingTime() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    }
    
    /// Отрисовка красивой обложки-заглушки для экрана блокировки
    private func drawPlaceholderImage(title: String) -> UIImage? {
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Задний фон - темно-фиолетовый градиент
        let colors = [UIColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1.0).cgColor,
                      UIColor(red: 0.15, green: 0.10, blue: 0.25, alpha: 1.0).cgColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil) else { return nil }
        context.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: 0, y: 400), options: [])
        
        // Рисуем светящуюся неоновую окружность по центру
        context.setLineWidth(6.0)
        context.setStrokeColor(UIColor(red: 0.62, green: 0.31, blue: 0.87, alpha: 0.8).cgColor)
        context.setShadow(offset: .zero, blur: 15.0, color: UIColor(red: 0.62, green: 0.31, blue: 0.87, alpha: 1.0).cgColor)
        context.addEllipse(in: CGRect(x: 100, y: 100, width: 200, height: 200))
        context.strokePath()
        
        // Текст - первая буква названия трека по центру
        let firstLetter = String(title.first ?? "🎵").uppercased()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 90),
            .foregroundColor: UIColor.white
        ]
        
        let textSize = firstLetter.size(withAttributes: attributes)
        let rect = CGRect(
            x: (400 - textSize.width) / 2,
            y: (400 - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        firstLetter.draw(in: rect, withAttributes: attributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Системные события воспроизведения (Наушники / Экран блокировки)
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            if self?.playbackState == .paused {
                self?.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            if self?.playbackState == .playing {
                self?.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        // Next command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        // Previous command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        // Scrubbing (перемотка из шторки)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }
}
