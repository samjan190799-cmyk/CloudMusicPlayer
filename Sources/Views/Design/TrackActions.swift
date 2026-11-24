import Foundation

/// Общие действия с треками, которые нужны на разных экранах
enum TrackActions {
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

    /// Запускает загрузку. Возвращает false, если источник не поддерживает скачивание.
    @discardableResult
    static func download(_ track: PlayerTrack) -> Bool {
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
        HapticManager.shared.triggerImpact(style: .light)
        AppRouter.shared.showToast("Загрузка началась", icon: "arrow.down.circle.fill")
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
