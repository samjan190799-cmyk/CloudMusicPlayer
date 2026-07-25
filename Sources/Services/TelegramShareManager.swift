import Foundation
import UIKit
import AVFoundation

/// Менеджер обработки аудиофайлов, переданных из Telegram и внешних приложений через Share Sheet ("Открыть в...")
final class TelegramShareManager {
    static let shared = TelegramShareManager()
    
    private init() {}
    
    /// Обрабатывает входящий URL аудиофайла из Telegram
    func handleIncomingAudioURL(_ url: URL) {
        Task.detached(priority: .userInitiated) {
            print("TelegramShareManager: Получен входящий файл из Telegram: \(url)")
            
            // Запрашиваем права доступа, если файл из внешнего контейнера
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped { url.stopAccessingSecurityScopedResource() }
            }
            
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let telegramFolder = documentsURL.appendingPathComponent("ImportedMusic", isDirectory: true)
            if !fileManager.fileExists(atPath: telegramFolder.path) {
                try? fileManager.createDirectory(at: telegramFolder, withIntermediateDirectories: true)
            }
            
            let fileName = url.lastPathComponent
            let destinationURL = telegramFolder.appendingPathComponent(fileName)
            
            // Если файл уже скопирован — удалим старую версию перед копированием
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            
            do {
                try fileManager.copyItem(at: url, to: destinationURL)
                print("TelegramShareManager: ✅ Файл успешно сохранен в ImportedMusic: \(fileName)")
                
                // Сканируем метаданные
                let metadata = await Self.extractMetadata(from: destinationURL)
                let title = metadata.title ?? destinationURL.deletingPathExtension().lastPathComponent
                let artist = metadata.artist ?? "Telegram Audio"
                
                var coverPath: String? = nil
                if let coverData = metadata.coverData {
                    coverPath = Self.saveCoverData(coverData, filename: "tg_\(fileName)")
                }
                
                let attributes = (try? fileManager.attributesOfItem(atPath: destinationURL.path)) ?? [:]
                let fileSize = (attributes[.size] as? Int64) ?? 0
                let relativePath = "ImportedMusic/\(fileName)"
                
                let localTrack = LocalTrack(
                    id: "tg_\(fileName)",
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
                    // Обновляем список сканера устройств
                    DeviceMediaScanner.shared.importFile(from: destinationURL)
                    
                    // Формируем PlayerTrack для моментального воспроизведения
                    let playerTrack = PlayerTrack(
                        id: localTrack.id,
                        title: localTrack.title,
                        artist: localTrack.artist ?? "Telegram Audio",
                        sourceName: "Telegram",
                        localURL: destinationURL,
                        remoteURL: nil,
                        googleFileId: nil,
                        localCoverURL: localTrack.localCoverURL,
                        duration: localTrack.duration
                    )
                    
                    // Моментально запускаем воспроизведение
                    AudioPlayerManager.shared.play(track: playerTrack, in: [playerTrack])
                    HapticManager.shared.triggerNotification(type: .success)
                }
            } catch {
                print("TelegramShareManager: ❌ Ошибка обработки входящего аудиофайла: \(error.localizedDescription)")
            }
        }
    }
    
    private struct AudioMetadata {
        var title: String?
        var artist: String?
        var duration: Double?
        var coverData: Data?
    }
    
    private static func extractMetadata(from fileURL: URL) async -> AudioMetadata {
        var result = AudioMetadata()
        let asset = AVURLAsset(url: fileURL)
        
        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if !seconds.isNaN && seconds > 0 { result.duration = seconds }
        }
        
        if let metadataItems = try? await asset.load(.commonMetadata) {
            for item in metadataItems {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    result.title = try? await item.load(.stringValue)
                case .commonKeyArtist:
                    result.artist = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    result.coverData = try? await item.load(.dataValue)
                default: break
                }
            }
        }
        return result
    }
    
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
        
        if let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: fileURL)
            return relativePath
        }
        return nil
    }
}
