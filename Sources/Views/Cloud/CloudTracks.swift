import Foundation

/// Источник облачной музыки
enum CloudProvider: String, CaseIterable, Identifiable, Hashable {
    case google
    case yandex
    case telegram

    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: return "Google Диск"
        case .yandex: return "Яндекс Диск"
        case .telegram: return "Telegram"
        }
    }

    var icon: String {
        switch self {
        case .google: return "externaldrive.fill"
        case .yandex: return "y.circle.fill"
        case .telegram: return "paperplane.fill"
        }
    }
}

/// Превращает облачные файлы в треки плеера с аккуратными названиями
enum CloudTracks {
    static func playerTrack(_ track: GoogleTrack) -> PlayerTrack {
        let display = TrackText.display(title: track.name, artist: "Google Drive")
        return PlayerTrack(
            id: track.id,
            title: display.title,
            artist: display.artist,
            sourceName: "Google Drive (Онлайн)",
            localURL: nil,
            remoteURL: nil,
            googleFileId: track.id
        )
    }

    static func playerTrack(_ track: YandexTrack) -> PlayerTrack {
        let display = TrackText.display(title: track.name, artist: "Яндекс Диск")
        return PlayerTrack(
            id: track.id,
            title: display.title,
            artist: display.artist,
            sourceName: "Яндекс Диск (Онлайн)",
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil
        )
    }

    /// Ключ обложки для Telegram-трека (своих обложек у Bot API нет)
    static func artworkKey(_ track: TelegramAudioTrack) -> ArtworkKey {
        ArtworkKey(id: "tg_\(track.id)", title: track.name, localCoverURL: nil, youTubeID: nil)
    }

    static func display(_ track: TelegramAudioTrack) -> TrackText.Display {
        TrackText.display(title: track.name, artist: track.performer ?? track.chatTitle ?? "Telegram")
    }

    /// Telegram выдаёт прямую ссылку только по запросу, поэтому трек играет сразу после её получения
    static func playTelegram(_ track: TelegramAudioTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        Task {
            guard let url = await TelegramService.shared.getDirectStreamURL(for: track.fileId) else {
                await MainActor.run {
                    AppRouter.shared.showToast("Не удалось получить файл из Telegram", icon: "exclamationmark.triangle.fill")
                }
                return
            }
            let info = CloudTracks.display(track)
            let playerTrack = PlayerTrack(
                id: "tg_\(track.id)",
                title: info.title,
                artist: info.artist,
                sourceName: "Telegram",
                localURL: nil,
                remoteURL: url,
                googleFileId: nil,
                localCoverURL: nil,
                duration: track.duration.map { Double($0) }
            )
            await MainActor.run {
                AudioPlayerManager.shared.play(track: playerTrack, in: [playerTrack])
            }
        }
    }
}
