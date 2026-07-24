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
        // Сканируем только доступную папку Documents при инициализации.
        // Доступ к Apple Music запрашиваем отложенно, чтобы избежать краша при старте приложения.
        scanFilesAppDocuments()
    }
    
    /// Запуск сканирования всех доступных локальных источников на устройстве
    func scanAllLocalSources() {
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanFilesAppDocuments()
            self.requestAndScanAppleMusic()
        }
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
                        
                        let relativePath = fileURL.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
                        let track = LocalTrack(
                            id: "file_\(fileURL.lastPathComponent)",
                            title: title,
                            source: .device,
                            relativePath: relativePath,
                            size: fileSize,
                            addedAt: (attributes[.modificationDate] as? Date) ?? Date(),
                            artist: "Файлы iOS",
                            duration: nil,
                            localCoverPath: nil
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
                    source: .device,
                    relativePath: assetURL.absoluteString,
                    size: 0,
                    addedAt: Date(),
                    artist: artist,
                    duration: item.playbackDuration,
                    localCoverPath: nil
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
