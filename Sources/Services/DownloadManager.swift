import Foundation
import Combine

/// Источник трека
enum TrackSource: String, Codable {
    case google = "google"
    case yandex = "yandex"
}

/// Модель локального (офлайн) трека
struct LocalTrack: Identifiable, Codable {
    let id: String
    let title: String
    let source: TrackSource
    let relativePath: String // Путь относительно директории Documents
    let size: Int64
    let addedAt: Date
    
    var localURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(relativePath)
    }
}

/// Состояние загрузки трека
enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
}

/// Менеджер загрузок и управления локальной медиатекой
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var localTracks: [LocalTrack] = []
    @Published var activeDownloads: [String: Double] = [:] // ID трека -> Прогресс (0.0 ... 1.0)
    
    private let libraryFileName = "Library.json"
    private let offlineFolder = "OfflineMusic"
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var urlSession: URLSession!
    
    override init() {
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        createOfflineDirectory()
        loadLibrary()
    }
    
    /// Создание папки для офлайн музыки
    private func createOfflineDirectory() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(offlineFolder)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
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
    
    /// Внутренний метод запуска задачи скачивания
    private func startDownload(trackId: String, title: String, source: TrackSource, request: URLRequest, size: Int64) {
        DispatchQueue.main.async {
            self.activeDownloads[trackId] = 0.0
        }
        
        let task = urlSession.downloadTask(with: request)
        // Будем сохранять метаданные о задаче во вспомогательном словаре
        task.taskDescription = "\(trackId)|\(title)|\(source.rawValue)|\(size)"
        downloadTasks[trackId] = task
        task.resume()
    }
    
    /// Отмена загрузки
    func cancelDownload(trackId: String) {
        if let task = downloadTasks[trackId] {
            task.cancel()
            downloadTasks.removeValue(forKey: trackId)
        }
        DispatchQueue.main.async {
            self.activeDownloads.removeValue(forKey: trackId)
        }
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
        let components = taskDescription.split(separator: "|")
        guard components.count >= 4 else { return }
        
        let trackId = String(components[0])
        let title = String(components[1])
        let sourceRaw = String(components[2])
        let size = Int64(components[3]) ?? 0
        let source = TrackSource(rawValue: sourceRaw) ?? .google
        
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
            
            let newTrack = LocalTrack(
                id: trackId,
                title: title,
                source: source,
                relativePath: relativeFilePath,
                size: size,
                addedAt: Date()
            )
            
            DispatchQueue.main.async {
                // Добавляем в локальный список
                self.localTracks.append(newTrack)
                self.saveLibrary()
                self.activeDownloads.removeValue(forKey: trackId)
                self.downloadTasks.removeValue(forKey: trackId)
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
}

// Вспомогательное расширение для получения безопасного имени файла
extension String {
    var uuidCompatible: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
