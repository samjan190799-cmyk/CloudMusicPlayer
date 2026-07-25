import Foundation
import MediaPlayer
import AVFoundation
import Combine
import UIKit

/// Сканер локальной медиатеки устройства (Apple Music / Приложение Музыка), Файлов (iOS Files App)
/// и импортированных файлов. Извлекает метаданные (артист, длительность, обложку) из аудиофайлов.
final class DeviceMediaScanner: ObservableObject {
    static let shared = DeviceMediaScanner()
    
    @Published var deviceTracks: [LocalTrack] = []
    @Published var filesAppTracks: [LocalTrack] = []
    @Published var importedTracks: [LocalTrack] = []
    @Published var isAppleMusicAuthorized = false
    @Published var isScanning = false
    
    // Постоянное хранилище списка импортированных треков
    private let importedTracksKey = "com.samvel.cloudmusicplayer.importedTracks"
    
    private init() {
        // Загружаем ранее импортированные треки
        loadImportedTracks()
        // Сканируем Documents при инициализации
        scanFilesAppDocuments()
    }
    
    /// Запуск сканирования всех доступных локальных источников на устройстве
    func scanAllLocalSources() {
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanFilesAppDocuments()
            self.requestAndScanAppleMusic()
            self.validateImportedTracks()
        }
    }

    
    /// Сканирование файлов, добавленных через приложение "Файлы" (iTunes / Files Sharing)
    /// Включает ВСЕ поддиректории Documents, кроме внутренних кэшей приложения.
    func scanFilesAppDocuments() {
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let supportedExtensions = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "wma", "opus"]
            // Внутренние папки приложения, которые не нужно сканировать
            let excludedFolders = ["MusicCache", "OfflineMusic", "OfflineCovers", "Inbox"]
            var foundTracks: [LocalTrack] = []
            
            if let enumerator = fileManager.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    // Проверяем, что файл не внутри внутренних папок приложения
                    let isExcluded = excludedFolders.contains(where: { fileURL.path.contains("/\($0)/") || fileURL.path.hasSuffix("/\($0)") })
                    if isExcluded { continue }
                    
                    let ext = fileURL.pathExtension.lowercased()
                    guard supportedExtensions.contains(ext) else { continue }
                    
                    let attributes = (try? fileManager.attributesOfItem(atPath: fileURL.path)) ?? [:]
                    let fileSize = (attributes[.size] as? Int64) ?? 0
                    
                    // Извлекаем метаданные из аудиофайла (артист, длительность, обложку)
                    let metadata = await Self.extractMetadata(from: fileURL)
                    
                    let rawTitle = fileURL.deletingPathExtension().lastPathComponent
                    let title = metadata.title ?? rawTitle
                    let artist = metadata.artist ?? "Файлы iOS"
                    
                    // Сохраняем обложку, если найдена
                    var coverPath: String? = nil
                    if let coverData = metadata.coverData {
                        coverPath = Self.saveCoverData(coverData, filename: "file_\(fileURL.lastPathComponent)")
                    }
                    
                    let relativePath = fileURL.path.replacingOccurrences(of: documentsURL.path + "/", with: "")
                    let track = LocalTrack(
                        id: "file_\(fileURL.lastPathComponent)",
                        title: title,
                        source: .device,
                        relativePath: relativePath,
                        size: fileSize,
                        addedAt: (attributes[.modificationDate] as? Date) ?? Date(),
                        artist: artist,
                        duration: metadata.duration,
                        localCoverPath: coverPath
                    )
                    foundTracks.append(track)
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
                let artist = item.artist ?? item.albumArtist ?? "Apple Music"
                
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
    
    // MARK: - Импорт файлов через Document Picker
    
    /// Импортирует аудиофайл из внешней директории (через UIDocumentPicker).
    /// Копирует файл в Documents/ImportedMusic/ и извлекает метаданные.
    func importFile(from sourceURL: URL) {
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let importFolder = documentsURL.appendingPathComponent("ImportedMusic", isDirectory: true)
            if !fileManager.fileExists(atPath: importFolder.path) {
                try? fileManager.createDirectory(at: importFolder, withIntermediateDirectories: true)
            }
            
            // Получаем доступ к файлу через security scope
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }
            
            let destinationURL = importFolder.appendingPathComponent(sourceURL.lastPathComponent)
            
            // Если файл уже существует — пропускаем
            if fileManager.fileExists(atPath: destinationURL.path) {
                print("DeviceMediaScanner: Файл уже существует: \(destinationURL.lastPathComponent)")
                await MainActor.run {
                    self.scanFilesAppDocuments() // Обновляем список
                }
                return
            }
            
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("DeviceMediaScanner: ✅ Файл импортирован: \(destinationURL.lastPathComponent)")
                
                // Извлекаем метаданные
                let metadata = await Self.extractMetadata(from: destinationURL)
                let rawTitle = destinationURL.deletingPathExtension().lastPathComponent
                let title = metadata.title ?? rawTitle
                let artist = metadata.artist ?? "Импорт"
                
                // Сохраняем обложку
                var coverPath: String? = nil
                if let coverData = metadata.coverData {
                    coverPath = Self.saveCoverData(coverData, filename: "imported_\(destinationURL.lastPathComponent)")
                }
                
                let attributes = (try? fileManager.attributesOfItem(atPath: destinationURL.path)) ?? [:]
                let fileSize = (attributes[.size] as? Int64) ?? 0
                
                let relativePath = "ImportedMusic/\(destinationURL.lastPathComponent)"
                let track = LocalTrack(
                    id: "imported_\(destinationURL.lastPathComponent)",
                    title: title,
                    source: .device,
                    relativePath: relativePath,
                    size: fileSize,
                    addedAt: Date(),
                    artist: artist,
                    duration: metadata.duration,
                    localCoverPath: coverPath
                )
                
                await MainActor.run {
                    // Проверяем дубликат
                    if !self.importedTracks.contains(where: { $0.id == track.id }) {
                        self.importedTracks.append(track)
                        self.saveImportedTracks()
                    }
                    // Перезапускаем полное сканирование, чтобы ImportedMusic/ тоже подхватился
                    self.scanFilesAppDocuments()
                }
            } catch {
                print("DeviceMediaScanner: ❌ Ошибка импорта файла: \(error.localizedDescription)")
            }
        }
    }
    
    /// Импорт нескольких файлов
    func importFiles(from urls: [URL]) {
        for url in urls {
            importFile(from: url)
        }
    }
    
    // MARK: - Хранение импортированных треков
    
    private func saveImportedTracks() {
        do {
            let data = try JSONEncoder().encode(importedTracks)
            UserDefaults.standard.set(data, forKey: importedTracksKey)
        } catch {
            print("DeviceMediaScanner: Ошибка сохранения импортированных треков: \(error)")
        }
    }
    
    private func loadImportedTracks() {
        guard let data = UserDefaults.standard.data(forKey: importedTracksKey) else { return }
        do {
            importedTracks = try JSONDecoder().decode([LocalTrack].self, from: data)
        } catch {
            print("DeviceMediaScanner: Ошибка загрузки импортированных треков: \(error)")
        }
    }
    
    /// Проверяет, что файлы импортированных треков ещё существуют на диске
    private func validateImportedTracks() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        importedTracks.removeAll { track in
            let fullPath = documentsURL.appendingPathComponent(track.relativePath).path
            return !fileManager.fileExists(atPath: fullPath)
        }
        saveImportedTracks()
    }
    
    // MARK: - Извлечение метаданных из аудиофайла
    
    /// Извлекает артиста, длительность и обложку из аудиофайла через AVAsset
    private struct AudioMetadata {
        var title: String?
        var artist: String?
        var duration: Double?
        var coverData: Data?
    }
    
    private static func extractMetadata(from fileURL: URL) async -> AudioMetadata {
        var result = AudioMetadata()
        
        let asset = AVURLAsset(url: fileURL)
        
        // Длительность
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            if !seconds.isNaN && seconds > 0 {
                result.duration = seconds
            }
        } catch {
            // Длительность недоступна — оставляем nil
        }
        
        // Метаданные (id3 теги)
        do {
            let metadataItems = try await asset.load(.commonMetadata)
            
            for item in metadataItems {
                guard let key = item.commonKey else { continue }
                
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue) {
                        result.title = value
                    }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue) {
                        result.artist = value
                    }
                case .commonKeyArtwork:
                    if let value = try? await item.load(.dataValue) {
                        result.coverData = value
                    }
                default:
                    break
                }
            }
        } catch {
            // Метаданные недоступны — оставляем дефолтные значения
        }
        
        return result
    }
    
    /// Сохраняет данные обложки на диск и возвращает относительный путь
    private static func saveCoverData(_ data: Data, filename: String) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let coversDir = documentsURL.appendingPathComponent("OfflineCovers", isDirectory: true)
        if !fileManager.fileExists(atPath: coversDir.path) {
            try? fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
        }
        
        let safeName = filename.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let relativePath = "OfflineCovers/\(safeName).jpg"
        let fileURL = documentsURL.appendingPathComponent(relativePath)
        
        // Если обложка уже существует — не перезаписываем
        guard !fileManager.fileExists(atPath: fileURL.path) else { return relativePath }
        
        // Конвертируем в JPEG с хорошим качеством
        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: fileURL)
            return relativePath
        }
        
        return nil
    }
}
