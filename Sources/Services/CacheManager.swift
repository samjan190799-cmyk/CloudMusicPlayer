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
    
    /// Удаление повреждённого/невоспроизводимого файла из кэша
    func removeCachedTrack(trackId: String) {
        DispatchQueue.main.async {
            guard let item = self.metadata[trackId] else { return }
            let fileURL = self.cacheURL.appendingPathComponent(item.relativePath)
            try? FileManager.default.removeItem(at: fileURL)
            self.metadata.removeValue(forKey: trackId)
            self.cachedTrackIds.remove(trackId)
            self.saveMetadata()
            print("CacheManager: 🗑 Удалён невоспроизводимый кэш для \(trackId)")
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
        } else if source == .youtube {
            YouTubeService.shared.getAudioURL(for: trackId) { [weak self] audioUrl in
                guard let audioUrl = audioUrl else { return }
                let request = URLRequest(url: audioUrl)
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
        let components = taskDescription.components(separatedBy: "|")
        guard components.count >= 4 else { return }
        
        // Название может содержать «|» (частое для YouTube), поэтому id берём с начала, а источник и размер — с конца
        let trackId = components[0]
        let title = components[1..<(components.count - 2)].joined(separator: "|")
        let sourceRaw = components[components.count - 2]
        let size = Int64(components[components.count - 1]) ?? 0
        
        guard AudioFileSniffer.isSuccessfulDownload(downloadTask) else {
            print("CacheManager: ❌ Сервер вернул ошибку при кэшировании \(trackId), файл отброшен")
            DispatchQueue.main.async {
                self.downloadTasks.removeValue(forKey: trackId)
            }
            return
        }
        
        let fileExtension = AudioFileSniffer.fileExtension(for: location)
        let safeFileName = "\(trackId.uuidCompatible).\(fileExtension)"
        let destinationURL = cacheURL.appendingPathComponent(safeFileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            var actualSize = size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path),
               let sizeValue = attributes[.size] as? Int64, sizeValue > 0 {
                actualSize = sizeValue
            }
            
            let newItem = CacheMetadata(
                id: trackId,
                title: title,
                relativePath: safeFileName,
                size: actualSize,
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

// MARK: - Определение формата аудиофайла

/// Определяет реальный контейнер аудиофайла по сигнатуре. AVPlayer выбирает демультиплексор
/// по расширению локального файла, поэтому M4A с YouTube, сохранённый как .mp3, не воспроизводится.
enum AudioFileSniffer {
    static func fileExtension(for fileURL: URL, fallback: String = "mp3") -> String {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return fallback }
        defer { try? handle.close() }
        let header = [UInt8](handle.readData(ofLength: 12))
        guard header.count >= 4 else { return fallback }

        if header.count >= 8, header[4] == 0x66, header[5] == 0x74, header[6] == 0x79, header[7] == 0x70 {
            return "m4a" // ....ftyp — MP4/M4A (AAC)
        }
        if header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 { return "mp3" } // ID3
        if header[0] == 0xFF, (header[1] & 0xE0) == 0xE0 {
            // MPEG sync: layer 0 у ADTS-AAC, остальное — MP3
            return (header[1] & 0x06) == 0 ? "aac" : "mp3"
        }
        if header[0] == 0x66, header[1] == 0x4C, header[2] == 0x61, header[3] == 0x43 { return "flac" } // fLaC
        if header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46 { return "wav" } // RIFF
        if header[0] == 0x4F, header[1] == 0x67, header[2] == 0x67, header[3] == 0x53 { return "ogg" } // OggS
        if header[0] == 0x1A, header[1] == 0x45, header[2] == 0xDF, header[3] == 0xA3 { return "webm" } // Matroska/WebM
        return fallback
    }

    /// Успешный ли HTTP-ответ у завершённой загрузки (иначе на диск попадёт HTML/JSON с ошибкой)
    static func isSuccessfulDownload(_ task: URLSessionTask) -> Bool {
        guard let http = task.response as? HTTPURLResponse else { return true }
        return (200...299).contains(http.statusCode)
    }
}
