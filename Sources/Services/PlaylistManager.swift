import Foundation
import UIKit

/// Модель трека внутри плейлиста
struct PlaylistTrack: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let sourceName: String
    let localRelativePath: String? // Если трек скачан локально
    let remoteURLString: String?   // Если есть прямая онлайн-ссылка
    let googleFileId: String?      // ID файла в Google Drive
    var localCoverPath: String? = nil // Путь к локальной обложке
    var duration: Double? = nil
    
    var localURL: URL? {
        guard let relativePath = localRelativePath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(relativePath)
    }
    
    var localCoverURL: URL? {
        guard let coverPath = localCoverPath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(coverPath)
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
    var coverPath: String? = nil // Путь к обложке плейлиста
    
    var coverURL: URL? {
        guard let coverPath = coverPath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(coverPath)
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Менеджер управления плейлистами пользователя
class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    static let favoritesUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    @Published var playlists: [Playlist] = []
    
    private let playlistsFileName = "Playlists.json"
    
    private init() {
        loadPlaylists()
        ensureFavoritesPlaylistExists()
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
    
    /// Установка кастомного фото/обложки для плейлиста
    func setCoverImage(_ image: UIImage, for playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent("PlaylistCovers", isDirectory: true)
        
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let filename = "playlist_cover_\(playlistId.uuidString).jpg"
        let fileURL = folderURL.appendingPathComponent(filename)
        let relativePath = "PlaylistCovers/\(filename)"
        
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL)
            playlists[index].coverPath = relativePath
            savePlaylists()
        }
    }
    
    /// Удаление плейлиста
    func deletePlaylist(id: UUID) {
        guard id != PlaylistManager.favoritesUUID else { return } // Нельзя удалить Избранное
        playlists.removeAll { $0.id == id }
        savePlaylists()
    }
    
    /// Добавление трека в плейлист
    func addTrack(_ track: PlaylistTrack, to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
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
    
    /// Проверка наличия плейлиста "Избранные песни" и его создание
    private func ensureFavoritesPlaylistExists() {
        if !playlists.contains(where: { $0.id == PlaylistManager.favoritesUUID }) {
            let favorites = Playlist(
                id: PlaylistManager.favoritesUUID,
                name: "Избранные песни",
                tracks: [],
                createdAt: Date()
            )
            playlists.insert(favorites, at: 0)
            savePlaylists()
        }
    }
    
    /// Добавление / Удаление трека из Избранного
    func toggleFavorite(track: PlaylistTrack) {
        if isTrackFavorite(trackId: track.id) {
            removeTrack(trackId: track.id, from: PlaylistManager.favoritesUUID)
        } else {
            addTrack(track, to: PlaylistManager.favoritesUUID)
            
            let autoDownload = UserDefaults.standard.object(forKey: "autoDownloadFavorites") as? Bool ?? true
            if autoDownload && !DownloadManager.shared.isDownloaded(trackId: track.id) {
                if track.sourceName == "YouTube" {
                    let ytTrack = YouTubeTrack(
                        id: track.id,
                        title: track.title,
                        uploader: track.artist,
                        duration: 0,
                        thumbnailUrl: "https://img.youtube.com/vi/\(track.id)/hqdefault.jpg"
                    )
                    DownloadManager.shared.downloadYouTubeTrack(ytTrack)
                } else if track.sourceName.contains("Google") {
                    if let googleTrack = GoogleDriveService.shared.tracks.first(where: { $0.id == track.id }) {
                        DownloadManager.shared.downloadGoogleTrack(googleTrack)
                    }
                } else if track.sourceName.contains("Яндекс") || track.sourceName.contains("Yandex") {
                    if let yandexTrack = YandexDiskService.shared.tracks.first(where: { $0.id == track.id }) {
                        DownloadManager.shared.downloadYandexTrack(yandexTrack)
                    }
                }
            }
        }
    }
    
    /// Проверка, добавлен ли трек в Избранное
    func isTrackFavorite(trackId: String) -> Bool {
        return isTrack(trackId, in: PlaylistManager.favoritesUUID)
    }
}

// Вспомогательное расширение для конвертации PlaylistTrack в PlayerTrack
extension PlaylistTrack {
    func toPlayerTrack() -> PlayerTrack {
        return PlayerTrack(
            id: id,
            title: title,
            artist: artist,
            sourceName: sourceName,
            localURL: localURL,
            remoteURL: remoteURL,
            googleFileId: googleFileId,
            localCoverURL: localCoverURL,
            duration: duration
        )
    }
}

// Вспомогательное расширение для безопасного поиска плейлиста
extension Array where Element == Playlist {
    func firstCompound(where id: UUID) -> Playlist? {
        return self.first(where: { $0.id == id })
    }
}
