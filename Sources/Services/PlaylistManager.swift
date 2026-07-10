import Foundation

/// Модель трека внутри плейлиста
struct PlaylistTrack: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let sourceName: String
    let localRelativePath: String? // Если трек скачан локально
    let remoteURLString: String?   // Если есть прямая онлайн-ссылка
    let googleFileId: String?      // ID файла в Google Drive
    
    var localURL: URL? {
        guard let relativePath = localRelativePath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(relativePath)
    }
    
    var remoteURL: URL? {
        guard let urlString = remoteURLString else { return nil }
        return URL(string: urlString)
    }
    
    static func == (lhs: PlaylistTrack, rhs: PlaylistTrack) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Модель плейлиста
struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var tracks: [PlaylistTrack]
    let createdAt: Date
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Менеджер управления плейлистами пользователя
class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published var playlists: [Playlist] = []
    
    private let playlistsFileName = "Playlists.json"
    
    private init() {
        loadPlaylists()
    }
    
    private var playlistsURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(playlistsFileName)
    }
    
    /// Загрузка плейлистов из локального JSON-файла
    func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: playlistsURL.path) else {
            self.playlists = []
            return
        }
        
        do {
            let data = try Data(contentsOf: playlistsURL)
            self.playlists = try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            print("Ошибка загрузки базы данных плейлистов: \(error)")
            self.playlists = []
        }
    }
    
    /// Сохранение плейлистов в JSON-файл
    func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: playlistsURL)
        } catch {
            print("Ошибка сохранения базы данных плейлистов: \(error)")
        }
    }
    
    /// Создание нового плейлиста
    func createPlaylist(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newPlaylist = Playlist(
            id: UUID(),
            name: name,
            tracks: [],
            createdAt: Date()
        )
        playlists.append(newPlaylist)
        savePlaylists()
    }
    
    /// Удаление плейлиста
    func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        savePlaylists()
    }
    
    /// Добавление трека в плейлист
    func addTrack(_ track: PlaylistTrack, to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        // Избегаем дубликатов по ID в рамках одного плейлиста
        if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
            playlists[index].tracks.append(track)
            savePlaylists()
        }
    }
    
    /// Удаление трека из конкретного плейлиста
    func removeTrack(trackId: String, from playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].tracks.removeAll { $0.id == trackId }
        savePlaylists()
    }
    
    /// Проверка, добавлен ли трек в плейлист
    func isTrack(_ trackId: String, in playlistId: UUID) -> Bool {
        guard let playlist = playlists.firstCompound(where: playlistId) else { return false }
        return playlist.tracks.contains(where: { $0.id == trackId })
    }
}

// Вспомогательное расширение для безопасного поиска плейлиста
extension Array where Element == Playlist {
    func firstCompound(where id: UUID) -> Playlist? {
        return self.first(where: { $0.id == id })
    }
}
