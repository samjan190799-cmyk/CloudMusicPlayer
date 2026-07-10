import Foundation
import YouTubeKit

/// Модель трека с YouTube
struct YouTubeTrack: Identifiable, Codable {
    let id: String // videoId
    let title: String
    let uploader: String
    let duration: Int // В секундах
    let thumbnailUrl: String
}

/// Сервис для работы с API альтернативного фронтенда YouTube (Invidious)
class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    @Published var tracks: [YouTubeTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = false
    
    private var currentQuery = ""
    private var currentPage = 1
    
    // Список рабочих публичных инстансов Invidious для переключения в случае ошибок
    // Примечание: инстансы используются ТОЛЬКО для поиска видео.
    // Получение аудиопотоков выполняется через YouTubeKit напрямую.
    private let apiInstances = [
        "https://yt.chocolatemoo53.com",
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de",
        "https://invidious.f5.si",
        "https://invidious.tiekoetter.com",
        "https://inv.zoomerville.com",
        "https://yewtu.be"
    ]
    
    private var activeInstanceIndex = 0
    
    private var currentInstance: String {
        return apiInstances[activeInstanceIndex]
    }
    
    private init() {}
    
    /// Переключение на резервный инстанс
    private func switchToNextInstance() {
        activeInstanceIndex = (activeInstanceIndex + 1) % apiInstances.count
        print("Переключение API Invidious на следующий инстанс: \(currentInstance)")
    }
    
    /// Поиск треков (видео) на YouTube
    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        self.currentQuery = query
        self.currentPage = 1
        self.canLoadMore = false
        self.isLoading = true
        self.errorMessage = nil
        
        performSearchRequest(query: query, page: 1, retryCount: 0)
    }
    
    /// Загрузка следующей страницы результатов
    func loadMore() {
        guard !isLoading && !currentQuery.isEmpty && canLoadMore else { return }
        
        self.isLoading = true
        let nextPage = currentPage + 1
        
        performSearchRequest(query: currentQuery, page: nextPage, retryCount: 0)
    }
    
    private func performSearchRequest(query: String, page: Int, retryCount: Int) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(currentInstance)/api/v1/search?q=\(encodedQuery)&type=video&page=\(page)"
        
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.errorMessage = "Неверный URL поиска"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Ошибка запроса к \(self.currentInstance): \(error.localizedDescription)")
                self.handleSearchFailure(query: query, page: page, retryCount: retryCount, errorMsg: error.localizedDescription)
                return
            }
            
            guard let data = data else {
                self.handleSearchFailure(query: query, page: page, retryCount: retryCount, errorMsg: "Пустой ответ сервера")
                return
            }
            
            do {
                let items = try JSONDecoder().decode([InvidiousSearchResult].self, from: data)
                DispatchQueue.main.async {
                    let newTracks = items.map { item in
                        YouTubeTrack(
                            id: item.videoId,
                            title: item.title,
                            uploader: item.author,
                            duration: item.lengthSeconds,
                            thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/hqdefault.jpg"
                        )
                    }
                    if page == 1 {
                        self.tracks = newTracks
                    } else {
                        self.tracks.append(contentsOf: newTracks)
                    }
                    self.currentPage = page
                    self.canLoadMore = !newTracks.isEmpty && newTracks.count >= 15
                    self.isLoading = false
                }
            } catch {
                print("Ошибка парсинга ответа от \(self.currentInstance): \(error.localizedDescription)")
                self.handleSearchFailure(query: query, page: page, retryCount: retryCount, errorMsg: "Ошибка декодирования результатов")
            }
        }.resume()
    }
    
    private func handleSearchFailure(query: String, page: Int, retryCount: Int, errorMsg: String) {
        if retryCount < apiInstances.count - 1 {
            switchToNextInstance()
            performSearchRequest(query: query, page: page, retryCount: retryCount + 1)
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Не удалось выполнить поиск. Проверьте подключение к сети. (\(errorMsg))"
            }
        }
    }
    
    // MARK: - Извлечение прямой ссылки на аудиопоток через YouTubeKit
    
    /// Извлечение прямой ссылки на аудиопоток по ID видео.
    /// Использует YouTubeKit — нативную Swift-библиотеку, которая извлекает URL
    /// напрямую с серверов YouTube без посредников (Invidious/Piped).
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                print("YouTubeKit: запрос потоков для видео \(videoId)...")
                let video = YouTube(videoID: videoId, methods: [.remote, .local])
                let streams = try await video.streams
                
                print("YouTubeKit: получено \(streams.count) потоков")
                
                // Получаем только аудио потоки
                let audioOnly = streams.filterAudioOnly()
                print("YouTubeKit: аудио-потоков: \(audioOnly.count)")
                
                // Логируем все доступные аудио потоки для диагностики
                for (i, stream) in audioOnly.enumerated() {
                    let codecStr = stream.audioCodec.map { String(describing: $0) } ?? "nil"
                    print("  [\(i)] ext=\(stream.fileExtension.rawValue), codec=\(codecStr), bitrate=\(stream.bitrate ?? 0)")
                }
                
                // ПРИОРИТЕТ 1: Ищем M4A (AAC) — единственный формат, который AVPlayer поддерживает
                let m4aStreams = audioOnly.filter { $0.fileExtension == .m4a }
                if let bestM4A = m4aStreams.highestAudioBitrateStream() {
                    print("YouTubeKit: выбран M4A поток, bitrate=\(bestM4A.bitrate ?? 0), url=\(bestM4A.url.absoluteString.prefix(80))...")
                    DispatchQueue.main.async { completion(bestM4A.url) }
                    return
                }
                
                // ПРИОРИТЕТ 2: MP4 аудио
                let mp4Streams = audioOnly.filter { $0.fileExtension == .mp4 }
                if let bestMP4 = mp4Streams.highestAudioBitrateStream() {
                    print("YouTubeKit: выбран MP4 аудио поток, bitrate=\(bestMP4.bitrate ?? 0)")
                    DispatchQueue.main.async { completion(bestMP4.url) }
                    return
                }
                
                // ПРИОРИТЕТ 3: Любой комбинированный поток MP4 (видео+аудио)
                let combined = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }
                if let fallback = combined.first {
                    print("YouTubeKit: используем комбинированный MP4 поток (видео+аудио)")
                    DispatchQueue.main.async { completion(fallback.url) }
                    return
                }
                
                // ПРИОРИТЕТ 4: Любой аудио поток (последний шанс, может не воспроизводиться)
                if let anyAudio = audioOnly.highestAudioBitrateStream() {
                    print("YouTubeKit: ПРЕДУПРЕЖДЕНИЕ — используем \(anyAudio.fileExtension.rawValue) поток (может не работать с AVPlayer)")
                    DispatchQueue.main.async { completion(anyAudio.url) }
                    return
                }
                
                print("YouTubeKit: НЕТ доступных аудиопотоков для видео \(videoId)")
                DispatchQueue.main.async { completion(nil) }
            } catch {
                print("YouTubeKit ОШИБКА для видео \(videoId): \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

// MARK: - Вспомогательные структуры ответов API Invidious (используются только для поиска)
struct InvidiousSearchResult: Codable {
    let videoId: String
    let title: String
    let author: String
    let lengthSeconds: Int
}

