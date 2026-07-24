import Foundation
import MediaPlayer
import Combine

/// Сканер локальной медиатеки устройства (Apple Music / Приложение Музыка) и Файлов (iOS Files App)
final class DeviceMediaScanner: ObservableObject {
    static let shared = DeviceMediaScanner()
    
    @Published var deviceTracks: [LocalTrack] = []
    @Published var filesAppTracks: [LocalTrack] = []
    @Published var isAppleMusicAuthorized = false
    @Published var isScanning = false
    
    private init() {
        scanAllLocalSources()
    }
    
    /// Запуск сканирования всех доступных локальных источников на устройстве
    func scanAllLocalSources() {
        DispatchQueue.main.async { self.isScanning = true }
        
        // 1. Сканирование приложения Файлы (Documents Folder)
        scanFilesAppDocuments()
        
        // 2. Сканирование приложения Музыка (Apple Music / iPod Library)
        requestAndScanAppleMusic()
    }
    
    /// Сканирование файлов, добавленных через приложение "Файлы" (iTunes / Files Sharing)
    func scanFilesAppDocuments() {
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let supportedExtensions = ["mp3", "m4a", "flac", "wav", "aac", "ogg"]
            var foundTracks: [LocalTrack] = []
            
            if let enumerator = fileManager.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if supportedExtensions.contains(ext) {
                        // Не включаем внутренние скрытые файлы из папки MusicCache
                        if fileURL.path.contains("MusicCache") || fileURL.path.contains("Downloads") {
                            continue
                        }
                        
                        let attributes = (try? fileManager.attributesOfItem(atPath: fileURL.path)) ?? [:]
                        let fileSize = (attributes[.size] as? Int64) ?? 0
                        let title = fileURL.deletingPathExtension().lastPathComponent
                        
                        let track = LocalTrack(
                            id: "file_\(fileURL.lastPathComponent)",
                            title: title,
                            artist: "Файлы iOS",
                            sourceName: "Файлы",
                            fileURL: fileURL,
                            fileSize: fileSize,
                            dateDownloaded: (attributes[.modificationDate] as? Date) ?? Date()
                        )
                        foundTracks.append(track)
                    }
                }
            }
            
            await MainActor.run {
                self.filesAppTracks = foundTracks
                self.isScanning = false
            }
        }
    }
    
    /// Запрос прав и получение треков из приложения "Музыка" (MPMediaQuery)
    func requestAndScanAppleMusic() {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            self.loadAppleMusicSongs()
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    self.loadAppleMusicSongs()
                }
            }
        default:
            break
        }
    }
    
    private func loadAppleMusicSongs() {
        Task.detached(priority: .userInitiated) {
            let query = MPMediaQuery.songs()
            guard let items = query.items else { return }
            
            var tracks: [LocalTrack] = []
            for item in items {
                guard let title = item.title, let assetURL = item.assetURL else { continue }
                let artist = item.artist ?? item.albumArtist ?? "Исполнитель Apple Music"
                
                let track = LocalTrack(
                    id: "applemusic_\(item.persistentID)",
                    title: title,
                    artist: artist,
                    sourceName: "Apple Music",
                    fileURL: assetURL,
                    fileSize: item.fileSize > 0 ? Int64(item.fileSize) : 0,
                    dateDownloaded: Date()
                )
                tracks.append(track)
            }
            
            await MainActor.run {
                self.isAppleMusicAuthorized = true
                self.deviceTracks = tracks
                self.isScanning = false
            }
        }
    }

}
