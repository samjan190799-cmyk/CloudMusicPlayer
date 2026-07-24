import Foundation
import AVFoundation
import MediaPlayer
import Combine
import WidgetKit
import UIKit

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
    var localCoverURL: URL? = nil // Локальный путь к обложке
    var duration: Double? = nil
    
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
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupWidgetSupport()
    }
    
    deinit {
        removeTimeObserver()
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func startBackgroundTask() {
        if Thread.isMainThread {
            self.executeStartBackgroundTask()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.executeStartBackgroundTask()
            }
        }
    }
    
    private func executeStartBackgroundTask() {
        endBackgroundTask()
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioPlaybackTransfer") { [weak self] in
            self?.endBackgroundTask()
        }
        print("AudioPlayerManager: Запущен фоновый таск \(backgroundTaskIdentifier)")
    }
    
    private func endBackgroundTask() {
        let taskId = backgroundTaskIdentifier
        guard taskId != .invalid else { return }
        backgroundTaskIdentifier = .invalid
        
        if Thread.isMainThread {
            UIApplication.shared.endBackgroundTask(taskId)
            print("AudioPlayerManager: Завершается фоновый таск \(taskId)")
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskId)
                print("AudioPlayerManager: Завершается фоновый таск \(taskId) (из фона)")
            }
        }
    }
    
    /// Настройка фонового аудио-сеанса
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try audioSession.setActive(true)
            
            // Подписка на прерывания (звонки, будильники)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
        } catch {
            print("Ошибка настройки AVAudioSession: \(error)")
        }
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            DispatchQueue.main.async { [weak self] in
                self?.player?.pause()
                self?.playbackState = .paused
                self?.updateNowPlayingPlaybackState()
            }
        } else if type == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                DispatchQueue.main.async { [weak self] in
                    self?.player?.play()
                    self?.playbackState = .playing
                    self?.updateNowPlayingPlaybackState()
                }
            }
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
        updateSharedPlayerState()
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
        currentTime = time
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                DispatchQueue.main.async {
                    self?.playbackState = self?.player?.rate == 0 ? .paused : .playing
                    self?.currentTime = time
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
        startBackgroundTask()
        playbackState = .loading
        currentTime = 0.0
        duration = track.duration ?? 0.0
        
        // Сброс старого плеера
        player?.pause()
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Активация аудиосессии перед началом воспроизведения
        try? AVAudioSession.sharedInstance().setActive(true)
        
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
            YandexDiskService.shared.getDownloadUrl(forPath: track.id) { [weak self] downloadUrl in
                guard let downloadUrl = downloadUrl else {
                    DispatchQueue.main.async {
                        self?.playbackState = .stopped
                        self?.endBackgroundTask()
                    }
                    return
                }
                DispatchQueue.main.async {
                    let item = AVPlayerItem(url: downloadUrl)
                    self?.setupPlayer(with: item, track: track)
                    self?.triggerCaching(for: track)
                }
            }
            return
        }
        // 6. Стриминг с YouTube (быстрое получение ссылки через YouTubeService + кеш)
        else if track.sourceName.contains("YouTube") {
            print("AudioPlayer: запрос аудио URL для YouTube трека: \(track.id) — \(track.title)")
            
            YouTubeService.shared.getAudioURL(for: track.id) { [weak self] audioUrl in
                guard let self = self else { return }
                
                if let audioUrl = audioUrl {
                    print("AudioPlayer: получен аудио URL: \(audioUrl.absoluteString.prefix(100))...")
                    
                    let headers = [
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                        "Referer": "https://www.youtube.com/"
                    ]
                    let assetOptions: [String: Any] = [
                        "AVURLAssetHTTPHeaderFieldsKey": headers,
                        "AVURLAssetPreferPreciseDurationAndTimingKey": false
                    ]
                    let asset = AVURLAsset(url: audioUrl, options: assetOptions)
                    let item = AVPlayerItem(asset: asset)
                    item.preferredForwardBufferDuration = 3 // Минимальная задержка предбуферизации
                    
                    DispatchQueue.main.async {
                        try? AVAudioSession.sharedInstance().setActive(true)
                        self.setupPlayer(with: item, track: track)
                        self.triggerCaching(for: track)
                    }
                } else {
                    print("AudioPlayer: ОШИБКА — не удалось получить аудио URL для YouTube трека \(track.id)")
                    DispatchQueue.main.async {
                        self.playbackState = .stopped
                        self.endBackgroundTask()
                    }
                }
            }
            return
        }
        guard let item = playerItem else {
            playbackState = .stopped
            endBackgroundTask()
            return
        }
        setupPlayer(with: item, track: track)
    }
    
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
        } else if track.sourceName.contains("Яндекс") || track.sourceName.contains("Yandex") {
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
                CacheManager.shared.cacheTrack(
                    trackId: track.id,
                    title: track.title,
                    source: .yandex,
                    size: 0,
                    googleFileId: nil,
                    yandexPath: track.id
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
        }
    }
    
    private func setupPlayer(with item: AVPlayerItem, track: PlayerTrack) {
        cancellables.removeAll()
        
        if let existingPlayer = player {
            existingPlayer.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        
        player?.volume = volume
        player?.isMuted = isMuted
        player?.automaticallyWaitsToMinimizeStalling = false // Отключаем искусственные задержки
        
        // Наблюдатели за окончанием трека
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        // Наблюдение за статусом готовности элемента
        item.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if let trackDuration = track.duration, trackDuration > 0 {
                        self?.duration = trackDuration
                    } else if !itemDuration.isNaN {
                        self?.duration = itemDuration
                    }
                    self?.updateNowPlayingInfo(for: track)
                    self?.playbackState = .playing
                    self?.player?.playImmediately(atRate: 1.0) // Моментальный запуск
                    self?.updateSharedPlayerState()
                    self?.endBackgroundTask()
                } else if status == .failed {
                    self?.playbackState = .stopped
                    self?.endBackgroundTask()
                    print("Ошибка воспроизведения элемента: \(String(describing: item.error))")
                }
            }
            .store(in: &cancellables)
    }
}
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        // Наблюдение за длительностью трека
        item.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if let trackDuration = track.duration, trackDuration > 0 {
                        self?.duration = trackDuration
                    } else if !itemDuration.isNaN {
                        self?.duration = itemDuration
                    }
                    self?.updateNowPlayingInfo(for: track)
                    self?.playbackState = .playing
                    self?.player?.play()
                    self?.updateSharedPlayerState()
                    self?.endBackgroundTask()
                } else if status == .failed {
                    self?.playbackState = .stopped
                    self?.endBackgroundTask()
                    print("Ошибка воспроизведения элемента: \(String(describing: item.error))")
                }
            }
            .store(in: &cancellables)
        // Обсервация текущего времени проигрывания
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            guard self.playbackState != .loading else { return }
            let seconds = CMTimeGetSeconds(time)
            if !seconds.isNaN {
                self.currentTime = seconds
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.repeatMode == .one {
                self.seek(to: 0)
                self.player?.play()
                self.playbackState = .playing
            } else {
                self.nextTrack()
            }
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
    
    // MARK: - Widget Support
    
    /// Регистрирует Darwin-уведомление для получения команд от Widget Extension.
    /// Darwin notifications — единственный кросс-процессный механизм, работающий
    /// когда основное приложение находится в фоне с активной аудио-сессией.
    private func setupWidgetSupport() {
        let name = kDarwinCommandName as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let ptr = observer else { return }
                let manager = Unmanaged<AudioPlayerManager>.fromOpaque(ptr).takeUnretainedValue()
                manager.handleWidgetCommand()
            },
            name,
            nil,
            .deliverImmediately
        )
        // Обновить виджет с текущим состоянием при старте
        updateSharedPlayerState()
    }
    
    /// Читает команду из shared UserDefaults и выполняет её.
    private func handleWidgetCommand() {
        let defaults = UserDefaults(suiteName: kAppGroupID)
        guard let command = defaults?.string(forKey: "pendingWidgetCommand") else { return }
        defaults?.removeObject(forKey: "pendingWidgetCommand")
        defaults?.synchronize()
        
        DispatchQueue.main.async { [weak self] in
            switch command {
            case "togglePlayPause":
                self?.togglePlayPause()
            case "skipNext":
                self?.nextTrack()
            case "skipPrevious":
                self?.previousTrack()
            default:
                break
            }
        }
    }
    
    /// Записывает текущее состояние плеера в shared UserDefaults и перезагружает таймлайны виджета.
    func updateSharedPlayerState() {
        let track = currentTrack
        let isPlaying = playbackState == .playing
        
        // Подготовка обложки (max 200×200 px для экономии места в UserDefaults)
        var coverData: Data? = nil
        if let coverURL = track?.localCoverURL,
           let image = UIImage(contentsOfFile: coverURL.path) {
            let targetSize = CGSize(width: 200, height: 200)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            coverData = resized.pngData()
        }
        
        let state = SharedPlayerState(
            trackTitle: track?.title ?? "CloudMusicPlayer",
            artistName: track?.artist ?? "Нет трека",
            isPlaying: isPlaying,
            coverData: coverData
        )
        state.save()
        
        // Перезагрузить таймлайны виджета
        WidgetCenter.shared.reloadAllTimelines()
    }
}


// MARK: - Конвертация в формат трека плейлиста
extension PlayerTrack {
    func toPlaylistTrack() -> PlaylistTrack {
        var relativePath: String? = nil
        if let localURL = localURL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let docsPath = docs.standardizedFileURL.path
            let filePath = localURL.standardizedFileURL.path
            if filePath.hasPrefix(docsPath) {
                var rel = filePath.replacingOccurrences(of: docsPath, with: "")
                if rel.hasPrefix("/") {
                    rel.removeFirst()
                }
                relativePath = rel
            } else {
                relativePath = localURL.lastPathComponent
            }
        }
        
        var coverRelPath: String? = nil
        if let localCoverURL = localCoverURL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let docsPath = docs.standardizedFileURL.path
            let filePath = localCoverURL.standardizedFileURL.path
            if filePath.hasPrefix(docsPath) {
                var rel = filePath.replacingOccurrences(of: docsPath, with: "")
                if rel.hasPrefix("/") {
                    rel.removeFirst()
                }
                coverRelPath = rel
            } else {
                coverRelPath = localCoverURL.lastPathComponent
            }
        }
        
        return PlaylistTrack(
            id: id,
            title: title,
            artist: artist,
            sourceName: sourceName,
            localRelativePath: relativePath,
            remoteURLString: remoteURL?.absoluteString,
            googleFileId: googleFileId,
            localCoverPath: coverRelPath,
            duration: duration
        )
    }
}
