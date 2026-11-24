import Foundation
import Combine

/// Запись истории прослушиваний
struct HistoryEntry: Codable, Identifiable {
    var track: PlaylistTrack
    var lastPlayed: Date
    var playCount: Int

    var id: String { track.id }
}

/// История прослушиваний: «Продолжить слушать» и «Часто слушаете» на главной.
/// Хранится локально в Documents/ListeningHistory.json.
final class ListeningHistory: ObservableObject {
    static let shared = ListeningHistory()

    /// Отсортировано от последнего к самому давнему
    @Published private(set) var entries: [HistoryEntry] = []

    private let fileName = "ListeningHistory.json"
    private let maxEntries = 300
    private var cancellable: AnyCancellable?

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }

    private init() {
        load()
        cancellable = AudioPlayerManager.shared.$currentTrack
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.record(track)
            }
    }

    /// Недавно прослушанные треки
    func recentTracks(limit: Int = 20) -> [PlaylistTrack] {
        Array(entries.prefix(limit)).map { $0.track }
    }

    /// Самые прослушиваемые треки (минимум 2 прослушивания)
    func topTracks(limit: Int = 10) -> [PlaylistTrack] {
        let top = entries
            .filter { $0.playCount >= 2 }
            .sorted { lhs, rhs in
                if lhs.playCount == rhs.playCount {
                    return lhs.lastPlayed > rhs.lastPlayed
                }
                return lhs.playCount > rhs.playCount
            }
        return Array(top.prefix(limit)).map { $0.track }
    }

    func playCount(for trackId: String) -> Int {
        entries.first(where: { $0.id == trackId })?.playCount ?? 0
    }

    func clear() {
        entries = []
        save()
    }

    private func record(_ track: PlayerTrack) {
        var updated = entries
        var count = 1
        if let index = updated.firstIndex(where: { $0.id == track.id }) {
            count = updated[index].playCount + 1
            updated.remove(at: index)
        }
        updated.insert(HistoryEntry(track: track.toPlaylistTrack(), lastPlayed: Date(), playCount: count), at: 0)
        if updated.count > maxEntries {
            updated.removeLast(updated.count - maxEntries)
        }
        entries = updated
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        let snapshot = entries
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
