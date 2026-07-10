import Foundation

/// Метаданные кэшированного файла
struct CacheMetadata: Codable {
    let id: String
    let title: String
    let relativePath: String
    let size: Int64
    var lastAccessed: Date
}

/// Менеджер автоматического кэширования онлайн-треков
class CacheManager: NSObject, ObservableObject {
    static let shared = CacheManager()
    
    @Published var cachedTrackIds: Set<String> = []
    
    private let cacheFolder = "MusicCache"
    private let metadataFileName = "CacheMetadata.json"
    private var metadata: [String: CacheMetadata] = [:]
    
    // Максимальный размер кэша (100 МБ)
    private let maxCacheSize: Int64 = 100 * 1024 * 1024
    
    private var urlSession: URLSession!
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    private override init() {
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        createCacheDirectory()
        loadMetadata()
    }
    
    private var cacheURL: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDirectory.appendingPathComponent(cacheFolder)
    }
    
    private var metadataURL: URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDirectory.appendingPathComponent(metadataFileName)
    }
    
    /// Создание директории кэша
    private func createCacheDirectory() {
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
    }
    
    /// Загрузка метаданных кэшированных файлов
    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataURL)
            let list = try JSONDecoder().decode([CacheMetadata].self, from: data)
            for item in list {
                metadata[item.id] = item
                cachedTrackIds.insert(item.id)
            }
        } catch {
            print("Ошибка загрузки метаданных кэша: \(error)")
        }
    }
    
    /// Сохранение метаданных кэша
    private func saveMetadata() {
        do {
            let list = Array(metadata.values)
            let data = try JSONEncoder().encode(list)
            try data.write(to: metadataURL)
        } catch {
            print("Ошибка сохранения метаданных кэша: \(error)")
        }
    }
    
    /// Получение URL кэшированного файла, если он существует
    func getCachedURL(for trackId: String) -> URL? {
        guard let item = metadata[trackId] else { return nil }
        let fileURL = cacheURL.appendingPathComponent(item.relativePath)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Обновляем время последнего доступа (LRU)
            metadata[trackId]?.lastAccessed = Date()
            saveMetadata()
            return fileURL
        } else {
            // Файл был удален из файловой системы вручную
            metadata.removeValue(forKey: trackId)
            DispatchQueue.main.async {
                self.cachedTrackIds.remove(trackId)
            }
            saveMetadata()
            return nil
        }
    }
    
    /// Проверка, кэширован ли файл
    func isCached(trackId: String) -> Bool {
        return cachedTrackIds.contains(trackId)
    }
    
    /// Запуск кэширования трека в фоновом режиме
    func cacheTrack(trackId: String, title: String, source: TrackSource, size: Int64, googleFileId: String?, yandexPath: String?) {
        guard !isCached(trackId: trackId) else { return }
        guard downloadTasks[trackId] == nil else { return }
        
        if source == .google {
            guard let request = GoogleDriveService.shared.makeDownloadRequest(forFileId: trackId) else { return }
            startDownload(trackId: trackId, title: title, source: source, size: size, request: request)
        } else if source == .yandex, let path = yandexPath {
            YandexDiskService.shared.getDownloadUrl(forPath: path) { [weak self] downloadUrl in
                guard let downloadUrl = downloadUrl else { return }
                let request = URLRequest(url: downloadUrl)
                self?.startDownload(trackId: trackId, title: title, source: source, size: size, request: request)
            }
        }
    }
    
    private func startDownload(trackId: String, title: String, source: TrackSource, size: Int64, request: URLRequest) {
        let task = urlSession.downloadTask(with: request)
        task.taskDescription = "\(trackId)|\(title)|\(source.rawValue)|\(size)"
        downloadTasks[trackId] = task
        task.resume()
    }
    
    /// Очистка кэша, если размер превысил лимит (100 МБ)
    private func cleanOldCacheIfNeeded() {
        let currentSize = metadata.values.reduce(0) { $0 + $1.size }
        guard currentSize > maxCacheSize else { return }
        
        // Сортируем файлы по дате последнего обращения (от старых к новым)
        let sorted = metadata.values.sorted { $0.lastAccessed < $1.lastAccessed }
        var bytesToRemove = currentSize - maxCacheSize
        
        for item in sorted {
            if bytesToRemove <= 0 { break }
            
            let fileURL = cacheURL.appendingPathComponent(item.relativePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            bytesToRemove -= item.size
            metadata.removeValue(forKey: item.id)
            cachedTrackIds.remove(item.id)
        }
        
        saveMetadata()
    }
}

// MARK: - URLSessionDownloadDelegate
extension CacheManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskDescription = downloadTask.taskDescription else { return }
        let components = taskDescription.split(separator: "|")
        guard components.count >= 4 else { return }
        
        let trackId = String(components[0])
        let title = String(components[1])
        let sourceRaw = String(components[2])
        let size = Int64(components[3]) ?? 0
        
        let fileExtension = "mp3"
        let safeFileName = "\(trackId.uuidCompatible).\(fileExtension)"
        let destinationURL = cacheURL.appendingPathComponent(safeFileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            let newItem = CacheMetadata(
                id: trackId,
                title: title,
                relativePath: safeFileName,
                size: size,
                lastAccessed: Date()
            )
            
            DispatchQueue.main.async {
                self.metadata[trackId] = newItem
                self.cachedTrackIds.insert(trackId)
                self.saveMetadata()
                self.downloadTasks.removeValue(forKey: trackId)
                self.cleanOldCacheIfNeeded()
            }
        } catch {
            print("Ошибка сохранения скачанного в кэш файла: \(error)")
            DispatchQueue.main.async {
                self.downloadTasks.removeValue(forKey: trackId)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Ошибка при кэшировании трека: \(error.localizedDescription)")
            guard let taskDescription = task.taskDescription else { return }
            let components = taskDescription.split(separator: "|")
            guard components.count >= 1 else { return }
            let trackId = String(components[0])
            
            DispatchQueue.main.async {
                self.downloadTasks.removeValue(forKey: trackId)
            }
        }
    }
}
