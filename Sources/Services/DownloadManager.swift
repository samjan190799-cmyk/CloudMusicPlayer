import Foundation
import Combine
import UIKit
import AVFoundation

/// Источник трека
enum TrackSource: String, Codable {
    case google = "google"
    case yandex = "yandex"
    case youtube = "youtube"
    
    var displayName: String {
        switch self {
        case .google: return "Google Drive"
        case .yandex: return "Яндекс Диск"
        case .youtube: return "YouTube"
        }
    }
}

/// Модель локального (офлайн) трека
struct LocalTrack: Identifiable, Codable {
    let id: String
    let title: String
    let source: TrackSource
    let relativePath: String // Путь относительно директории Documents
    let size: Int64
    let addedAt: Date
    var artist: String? = nil
    var duration: Double? = nil
    var localCoverPath: String? = nil
    
    var localURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(relativePath)
    }
    
    var localCoverURL: URL? {
        guard let coverPath = localCoverPath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(coverPath)
    }
}

/// Состояние загрузки трека
enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

/// Модель активной фоновой загрузки
struct ActiveDownload: Identifiable {
    let id: String // trackId
    let title: String
    let source: TrackSource
    let progress: Double
}

/// Менеджер загрузок и управления локальной медиатекой
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var localTracks: [LocalTrack] = []
    @Published var activeDownloads: [String: Double] = [:] // ID трека -> Прогресс (0.0 ... 1.0)
    
    private let libraryFileName = "Library.json"
    private let offlineFolder = "OfflineMusic"
    private let coversFolder = "OfflineCovers"
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var urlSession: URLSession!
    
    override init() {
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        createOfflineDirectory()
        createCoversDirectory()
        loadLibrary()
    }
    
    /// Список активных загрузок в удобном для UI формате
    var activeDownloadsList: [ActiveDownload] {
        var list: [ActiveDownload] = []
        for (trackId, progress) in activeDownloads {
            if let task = downloadTasks[trackId],
               let taskDescription = task.taskDescription {
                let components = taskDescription.split(separator: "|", omittingEmptySubsequences: false)
                if components.count >= 3 {
                    let title = String(components[1])
                    let sourceRaw = String(components[2])
                    let source = TrackSource(rawValue: sourceRaw) ?? .youtube
                    list.append(ActiveDownload(id: trackId, title: title, source: source, progress: progress))
                }
            } else {
                list.append(ActiveDownload(id: trackId, title: "Загрузка...", source: .youtube, progress: progress))
            }
        }
        return list.sorted { $0.title < $1.title }
    }
    
    /// Отмена активной загрузки по ID трека
    func cancelDownload(trackId: String) {
        if let task = downloadTasks[trackId] {
            task.cancel()
        }
        DispatchQueue.main.async {
            self.activeDownloads.removeValue(forKey: trackId)
            self.downloadTasks.removeValue(forKey: trackId)
        }
    }
    
    /// Создание папки для офлайн музыки
    private func createOfflineDirectory() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(offlineFolder)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }
    
    /// Создание папки для обложек офлайн
    private func createCoversDirectory() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(coversFolder)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }
    
    /// Фоновое скачивание изображения обложки
    func downloadCover(from urlString: String, filename: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let safeFilename = "\(filename.uuidCompatible).jpg"
            let relativePath = "\(self.coversFolder)/\(safeFilename)"
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent(relativePath)
            
            do {
                try data.write(to: fileURL)
                completion(relativePath)
            } catch {
                print("Ошибка при записи обложки: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    /// Путь к файлу базы данных Library.json
    private var libraryURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(libraryFileName)
    }
    
    /// Загрузка базы данных библиотеки
    func loadLibrary() {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else {
            self.localTracks = []
            return
        }
        
        do {
            let data = try Data(contentsOf: libraryURL)
            self.localTracks = try JSONDecoder().decode([LocalTrack].self, from: data)
        } catch {
            print("Ошибка загрузки медиатеки: \(error)")
            self.localTracks = []
        }
    }
    
    /// Сохранение базы данных библиотеки
    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(localTracks)
            try data.write(to: libraryURL)
        } catch {
            print("Ошибка сохранения медиатеки: \(error)")
        }
    }
    
    /// Проверка, скачан ли трек
    func isDownloaded(trackId: String) -> Bool {
        return localTracks.contains(where: { $0.id == trackId })
    }
    
    /// Получение статуса загрузки трека
    func getDownloadStatus(for trackId: String) -> DownloadStatus {
        if isDownloaded(trackId: trackId) {
            return .downloaded
        }
        if let progress = activeDownloads[trackId] {
            return .downloading(progress: progress)
        }
        return .notDownloaded
    }
    
    /// Запуск загрузки трека с Google Диска
    func downloadGoogleTrack(_ track: GoogleTrack) {
        let trackId = track.id
        guard activeDownloads[trackId] == nil else { return }
        
        guard let request = GoogleDriveService.shared.makeDownloadRequest(forFileId: trackId) else {
            print("Не удалось создать запрос для Google Drive")
            return
        }
        
        startDownload(trackId: trackId, title: track.name, source: .google, request: request, size: track.sizeInBytes)
    }
    
    /// Запуск загрузки трека с Яндекс Диска
    func downloadYandexTrack(_ track: YandexTrack) {
        let trackId = track.id
        guard activeDownloads[trackId] == nil else { return }
        
        // Яндекс Диск требует сначала получить URL на скачивание, затем выполнить GET
        YandexDiskService.shared.getDownloadUrl(forPath: track.path) { [weak self] downloadUrl in
            guard let downloadUrl = downloadUrl else {
                print("Не удалось получить ссылку для скачивания с Яндекса")
                return
            }
            
            let request = URLRequest(url: downloadUrl)
            self?.startDownload(trackId: trackId, title: track.name, source: .yandex, request: request, size: track.size ?? 0)
        }
    }
    
    /// Запуск загрузки трека с YouTube
    func downloadYouTubeTrack(_ track: YouTubeTrack) {
        let trackId = track.id
        guard activeDownloads[trackId] == nil else { return }
        
        YouTubeService.shared.getAudioURL(for: trackId) { [weak self] audioUrl in
            guard let audioUrl = audioUrl else {
                print("Не удалось получить ссылку для скачивания с YouTube")
                return
            }
            
            var request = URLRequest(url: audioUrl)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
            self?.startDownload(
                trackId: trackId,
                title: track.title,
                source: .youtube,
                request: request,
                size: 0,
                artist: track.uploader,
                duration: Double(track.duration),
                thumbnailUrl: track.thumbnailUrl
            )
        }
    }
    
    /// Внутренний метод запуска задачи скачивания
    private func startDownload(
        trackId: String,
        title: String,
        source: TrackSource,
        request: URLRequest,
        size: Int64,
        artist: String? = nil,
        duration: Double? = nil,
        thumbnailUrl: String? = nil
    ) {
        DispatchQueue.main.async {
            self.activeDownloads[trackId] = 0.0
        }
        
        let task = urlSession.downloadTask(with: request)
        
        let artistStr = artist ?? ""
        let durationStr = duration != nil ? String(duration!) : "0"
        let thumbnailStr = thumbnailUrl ?? ""
        
        // Добавляем метаданные в описание задачи
        task.taskDescription = "\(trackId)|\(title)|\(source.rawValue)|\(size)|\(artistStr)|\(durationStr)|\(thumbnailStr)"
        downloadTasks[trackId] = task
        task.resume()
    }
    
    /// Удаление локального файла трека и его записи из медиатеки
    func deleteTrack(trackId: String) {
        guard let index = localTracks.firstIndex(where: { $0.id == trackId }) else { return }
        let track = localTracks[index]
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: track.localURL.path) {
            try? fileManager.removeItem(at: track.localURL)
        }
        
        localTracks.remove(at: index)
        saveLibrary()
    }
}

// Реализация URLSessionDelegate для отслеживания прогресса и завершения загрузки
extension DownloadManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskDescription = downloadTask.taskDescription else { return }
        let components = taskDescription.split(separator: "|")
        guard components.count >= 1 else { return }
        let trackId = String(components[0])
        
        let expectedBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (Int64(components[3]) ?? 1)
        let progress = Double(totalBytesWritten) / Double(expectedBytes)
        
        DispatchQueue.main.async {
            self.activeDownloads[trackId] = min(max(progress, 0.0), 1.0)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskDescription = downloadTask.taskDescription else { return }
        let components = taskDescription.components(separatedBy: "|")
        guard components.count >= 4 else { return }
        
        let trackId = String(components[0])
        let title = String(components[1])
        let sourceRaw = String(components[2])
        let size = Int64(components[3]) ?? 0
        let source = TrackSource(rawValue: sourceRaw) ?? .google
        
        // Считываем опциональные параметры
        let artist: String? = components.count >= 5 && !components[4].isEmpty ? String(components[4]) : nil
        let duration: Double? = components.count >= 6 && !components[5].isEmpty ? Double(components[5]) : nil
        let thumbnailUrl: String? = components.count >= 7 && !components[6].isEmpty ? String(components[6]) : nil
        
        // Генерируем уникальное локальное имя файла для избежания конфликтов
        let fileExtension = "mp3" // По умолчанию mp3
        let safeFileName = "\(trackId.uuidCompatible).\(fileExtension)"
        let relativeFilePath = "\(offlineFolder)/\(safeFileName)"
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsDirectory.appendingPathComponent(relativeFilePath)
        
        // Если файл уже существует, удаляем его перед копированием
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.moveItem(at: location, to: destinationURL)
            
            // Вычисляем реальный размер файла на диске после успешного скачивания
            var fileSize: Int64 = size
            if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
               let sizeValue = attributes[.size] as? Int64 {
                fileSize = sizeValue
            }
            
            // Замыкание для записи в библиотеку
            let saveTrack = { (finalTitle: String, finalArtist: String?, finalDuration: Double?, finalCoverPath: String?) in
                let newTrack = LocalTrack(
                    id: trackId,
                    title: finalTitle,
                    source: source,
                    relativePath: relativeFilePath,
                    size: fileSize,
                    addedAt: Date(),
                    artist: finalArtist,
                    duration: finalDuration,
                    localCoverPath: finalCoverPath
                )
                
                DispatchQueue.main.async {
                    self.localTracks.append(newTrack)
                    self.saveLibrary()
                    self.activeDownloads.removeValue(forKey: trackId)
                    self.downloadTasks.removeValue(forKey: trackId)
                }
            }
            
            // Вспомогательная функция для продолжения сохранения
            func proceedSaving(finalTitle: String, finalArtist: String?, finalDuration: Double?, finalCoverPath: String?) {
                if let coverPath = finalCoverPath {
                    // Используем извлеченный кадр
                    saveTrack(finalTitle, finalArtist, finalDuration, coverPath)
                } else if source == .youtube {
                    if let thumbUrl = thumbnailUrl {
                        self.downloadCover(from: thumbUrl, filename: trackId) { coverPath in
                            saveTrack(finalTitle, finalArtist, finalDuration, coverPath)
                        }
                    } else {
                        saveTrack(finalTitle, finalArtist, finalDuration, nil)
                    }
                } else {
                    // Скачано из облака (Google/Yandex) - ищем на YouTube
                    let searchQuery = finalTitle.sanitizedForSearch
                    YouTubeService.shared.findMetadata(for: searchQuery) { ytTrack in
                        if let ytTrack = ytTrack {
                            self.downloadCover(from: ytTrack.thumbnailUrl, filename: trackId) { coverPath in
                                saveTrack(finalTitle, ytTrack.uploader, Double(ytTrack.duration), coverPath)
                            }
                        } else {
                            saveTrack(finalTitle, nil, nil, nil)
                        }
                    }
                }
            }
            
            // Проверяем настройки ИИ
            let providerRaw = UserDefaults.standard.string(forKey: "selectedAIProvider") ?? AIProvider.gemini.rawValue
            let provider = AIProvider(rawValue: providerRaw) ?? .gemini
            let activeApiKey: String
            switch provider {
            case .gemini: activeApiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
            case .chatgpt: activeApiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
            case .claude: activeApiKey = UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
            }
            
            let isAIEnabled = !activeApiKey.isEmpty
            
            if isAIEnabled && source == .youtube {
                print("ИИ: очистка метаданных для видео '\(title)'...")
                AIService.shared.cleanMetadata(rawTitle: title) { aiTitle, aiArtist in
                    let finalTitle = aiTitle ?? title
                    let finalArtist = aiArtist ?? artist
                    print("ИИ: очищенные метаданные -> Title: '\(finalTitle)', Artist: '\(finalArtist ?? "")'")
                    
                    print("ИИ: получение видеопотока для захвата кадра...")
                    YouTubeService.shared.getVideoURL(for: trackId) { videoURL in
                        if let videoURL = videoURL {
                            self.extractFrame(from: videoURL, filename: trackId) { coverPath in
                                proceedSaving(finalTitle: finalTitle, finalArtist: finalArtist, finalDuration: duration, finalCoverPath: coverPath)
                            }
                        } else {
                            proceedSaving(finalTitle: finalTitle, finalArtist: finalArtist, finalDuration: duration, finalCoverPath: nil)
                        }
                    }
                }
            } else {
                proceedSaving(finalTitle: title, finalArtist: artist, finalDuration: duration, finalCoverPath: nil)
            }
            
        } catch {
            print("Ошибка при сохранении скачанного файла: \(error)")
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: trackId)
                self.downloadTasks.removeValue(forKey: trackId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Ошибка загрузки: \(error.localizedDescription)")
            guard let taskDescription = task.taskDescription else { return }
            let components = taskDescription.split(separator: "|")
            guard components.count >= 1 else { return }
            let trackId = String(components[0])
            
            DispatchQueue.main.async {
                self.activeDownloads.removeValue(forKey: trackId)
                self.downloadTasks.removeValue(forKey: trackId)
            }
        }
    }
    
    /// Извлечение кадра из видеопотока на 15-й секунде, кадрирование и сжатие в 800x800
    func extractFrame(from videoURL: URL, filename: String, completion: @escaping (String?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let time = CMTime(seconds: 15.0, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, _, error in
            guard let self = self else {
                completion(nil)
                return
            }
            if let cgImage = cgImage {
                let rawImage = UIImage(cgImage: cgImage)
                // Сжимаем кадр до 800x800 (квадрат высокого разрешения)
                let resizedImage = rawImage.resized(to: CGSize(width: 800, height: 800)) ?? rawImage
                
                if let data = resizedImage.jpegData(compressionQuality: 0.85) {
                    let fileManager = FileManager.default
                    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        completion(nil)
                        return
                    }
                    let relativePath = "\(self.coversFolder)/\(filename.uuidCompatible).jpg"
                    let fileURL = documentsURL.appendingPathComponent(relativePath)
                    
                    // Убедимся, что директория существует
                    let coversDir = documentsURL.appendingPathComponent(self.coversFolder, isDirectory: true)
                    try? fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
                    
                    do {
                        try data.write(to: fileURL)
                        print("Кадр успешно извлечен, сжат в 800x800 и сохранен: \(relativePath)")
                        completion(relativePath)
                    } catch {
                        print("Ошибка сохранения кадра на диск: \(error)")
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            } else {
                print("Ошибка извлечения кадра из видеопотока: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
            }
        }
    }
}

// Вспомогательное расширение для получения безопасного имени файла
extension String {
    var uuidCompatible: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
    
    var sanitizedForSearch: String {
        var clean = self
        let extensions = [".mp3", ".wav", ".m4a", ".flac", ".aac", ".ogg", ".wma"]
        for ext in extensions {
            if clean.lowercased().hasSuffix(ext) {
                clean = String(clean.dropLast(ext.count))
            }
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Расширение для быстрого изменения размера изображений обложек
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
