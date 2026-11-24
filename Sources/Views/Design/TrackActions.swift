import Foundation

/// Общие действия с треками, которые нужны на разных экранах
enum TrackActions {
    /// Тап по треку в списке: повторный тап по текущему треку ставит паузу/продолжает,
    /// а не перезапускает его
    static func playOrToggle(_ track: PlayerTrack, in queue: [PlayerTrack]) {
        let player = AudioPlayerManager.shared
        if player.currentTrack?.id == track.id && player.playbackState != .stopped {
            if player.playbackState != .loading {
                HapticManager.shared.triggerImpact(style: .light)
                player.togglePlayPause()
            }
            return
        }
        player.play(track: track, in: queue)
    }

    /// Можно ли скачать трек для офлайн-прослушивания
    static func canDownload(_ track: PlayerTrack) -> Bool {
        let downloads = DownloadManager.shared
        guard !downloads.isDownloaded(trackId: track.id), downloads.activeDownloads[track.id] == nil else {
            return false
        }
        if let localURL = track.localURL, FileManager.default.fileExists(atPath: localURL.path) {
            return false
        }
        return youTubeTrack(for: track) != nil
            || googleTrack(for: track) != nil
            || yandexTrack(for: track) != nil
    }

    /// Скачивает всё, что ещё не сохранено. Возвращает число запущенных загрузок.
    @discardableResult
    static func downloadAll(_ tracks: [PlayerTrack]) -> Int {
        var started = 0
        for track in tracks where canDownload(track) {
            if download(track, announce: false) {
                started += 1
            }
        }
        if started > 0 {
            HapticManager.shared.triggerNotification(type: .success)
            AppRouter.shared.showToast("Скачиваем \(Formatters.tracks(started))", icon: "arrow.down.circle.fill")
        } else {
            AppRouter.shared.showToast("Всё уже скачано", icon: "checkmark.circle.fill")
        }
        return started
    }

    /// Запускает загрузку. Возвращает false, если источник не поддерживает скачивание.
    @discardableResult
    static func download(_ track: PlayerTrack, announce: Bool = true) -> Bool {
        let downloads = DownloadManager.shared
        if let youTube = youTubeTrack(for: track) {
            downloads.downloadYouTubeTrack(youTube)
        } else if let google = googleTrack(for: track) {
            downloads.downloadGoogleTrack(google)
        } else if let yandex = yandexTrack(for: track) {
            downloads.downloadYandexTrack(yandex)
        } else {
            return false
        }
        if announce {
            HapticManager.shared.triggerImpact(style: .light)
            AppRouter.shared.showToast("Загрузка началась", icon: "arrow.down.circle.fill")
        }
        return true
    }

    private static func youTubeTrack(for track: PlayerTrack) -> YouTubeTrack? {
        guard track.sourceName.contains("YouTube") || track.sourceName == "Аудиокниги" else { return nil }
        return YouTubeTrack(
            id: track.id,
            title: track.title,
            uploader: track.artist,
            duration: Int(track.duration ?? 0),
            thumbnailUrl: "https://img.youtube.com/vi/\(track.id)/hqdefault.jpg"
        )
    }

    private static func googleTrack(for track: PlayerTrack) -> GoogleTrack? {
        guard track.googleFileId != nil || track.sourceName.contains("Google") else { return nil }
        return GoogleDriveService.shared.tracks.first(where: { $0.id == track.id })
    }

    private static func yandexTrack(for track: PlayerTrack) -> YandexTrack? {
        guard track.sourceName.contains("Яндекс") || track.sourceName.contains("Yandex") else { return nil }
        return YandexDiskService.shared.tracks.first(where: { $0.id == track.id })
    }
}
