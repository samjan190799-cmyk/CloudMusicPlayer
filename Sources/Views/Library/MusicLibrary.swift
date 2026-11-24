import Foundation
import Combine

/// Единая медиатека: скачанное, импортированное, файлы из «Файлов» и музыка iPhone
enum MusicLibrary {
    /// Объединяет все локальные источники без дубликатов
    static func allTracks(
        downloads: [LocalTrack],
        imported: [LocalTrack],
        files: [LocalTrack],
        device: [LocalTrack]
    ) -> [LocalTrack] {
        var seenIDs = Set<String>()
        var seenFiles = Set<String>()
        var result: [LocalTrack] = []
        result.reserveCapacity(downloads.count + imported.count + files.count + device.count)

        for track in downloads + imported + files + device {
            let fileKey = track.relativePath.hasPrefix("ipod-library://")
                ? track.relativePath
                : track.localURL.standardizedFileURL.path
            if seenIDs.contains(track.id) || seenFiles.contains(fileKey) {
                continue
            }
            seenIDs.insert(track.id)
            seenFiles.insert(fileKey)
            result.append(track)
        }
        return result
    }

    /// Текущее содержимое медиатеки
    static func current() -> [LocalTrack] {
        let scanner = DeviceMediaScanner.shared
        return allTracks(
            downloads: DownloadManager.shared.localTracks,
            imported: scanner.importedTracks,
            files: scanner.filesAppTracks,
            device: scanner.deviceTracks
        )
    }

    /// Человекочитаемое название источника локального трека
    static func sourceLabel(for track: LocalTrack) -> String {
        if track.relativePath.hasPrefix("ipod-library://") {
            return "Музыка iPhone"
        }
        switch track.source {
        case .youtube: return "YouTube"
        case .google: return "Google Диск"
        case .yandex: return "Яндекс Диск"
        case .device: return "Файлы"
        }
    }
}

// MARK: - Подборки

enum Mixes {
    /// «Микс дня»: избранное, любимое и случайное из медиатеки.
    /// Порядок стабилен в течение дня и меняется на следующий.
    static func dailyMix(
        library: [LocalTrack],
        favorites: [PlaylistTrack],
        history: ListeningHistory,
        limit: Int = 40
    ) -> [PlayerTrack] {
        var generator = SeededGenerator(seed: daySeed())
        var seen = Set<String>()
        var mix: [PlayerTrack] = []

        func add(_ track: PlayerTrack) {
            guard !seen.contains(track.id) else { return }
            seen.insert(track.id)
            mix.append(track)
        }

        favorites.shuffled(using: &generator).prefix(15).forEach { add($0.toPlayerTrack()) }
        history.topTracks(limit: 10).forEach { add($0.toPlayerTrack()) }
        library.shuffled(using: &generator).prefix(limit).forEach { add($0.toPlayerTrack()) }
        history.recentTracks(limit: 10).forEach { add($0.toPlayerTrack()) }

        return Array(mix.shuffled(using: &generator).prefix(limit))
    }

    private static func daySeed() -> UInt64 {
        let days = Int(Date().timeIntervalSince1970 / 86_400)
        return UInt64(max(days, 1)) &* 2_654_435_761
    }
}

/// Детерминированный генератор (SplitMix64) для стабильного «микса дня»
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Хранилище медиатеки


/// Объединённая медиатека, которая пересчитывается только при изменении списков треков
/// (а не на каждый тик прогресса загрузки, как DownloadManager).
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var tracks: [LocalTrack] = []

    private var cancellable: AnyCancellable?

    private init() {
        tracks = MusicLibrary.current()

        let downloads = DownloadManager.shared
        let scanner = DeviceMediaScanner.shared
        cancellable = Publishers.CombineLatest4(
            downloads.$localTracks,
            scanner.$importedTracks,
            scanner.$filesAppTracks,
            scanner.$deviceTracks
        )
        .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
        .map { MusicLibrary.allTracks(downloads: $0.0, imported: $0.1, files: $0.2, device: $0.3) }
        .sink { [weak self] merged in
            self?.tracks = merged
        }
    }
}
