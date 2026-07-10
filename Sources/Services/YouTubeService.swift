import Foundation

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
    
    /// Извлечение прямой ссылки на аудиопоток по ID видео
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        performAudioURLRequest(videoId: videoId, retryCount: 0, completion: completion)
    }
    
    private func performAudioURLRequest(videoId: String, retryCount: Int, completion: @escaping (URL?) -> Void) {
        let urlString = "\(currentInstance)/api/v1/videos/\(videoId)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if error != nil || data == nil {
                self.handleAudioURLFailure(videoId: videoId, retryCount: retryCount, completion: completion)
                return
            }
            
            do {
                let videoInfo = try JSONDecoder().decode(InvidiousVideoInfo.self, from: data!)
                
                // Фильтруем форматы, содержащие только аудио (audio/mp4 или audio/webm)
                let audioFormats = videoInfo.adaptiveFormats.filter { $0.mimeType.contains("audio") }
                
                // Предпочитаем mp4 (m4a) для лучшей совместимости с AVPlayer
                if let bestAudio = audioFormats.first(where: { $0.mimeType.contains("mp4") }) ?? audioFormats.first {
                    // Некоторые инстансы могут отдавать относительные ссылки, приведем их к абсолютным
                    var absoluteUrlString = bestAudio.url
                    if absoluteUrlString.hasPrefix("/") {
                        absoluteUrlString = self.currentInstance + absoluteUrlString
                    }
                    
                    if let url = URL(string: absoluteUrlString) {
                        completion(url)
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            } catch {
                print("Ошибка декодирования аудиопотока от \(self.currentInstance): \(error.localizedDescription)")
                self.handleAudioURLFailure(videoId: videoId, retryCount: retryCount, completion: completion)
            }
        }.resume()
    }
    
    private func handleAudioURLFailure(videoId: String, retryCount: Int, completion: @escaping (URL?) -> Void) {
        if retryCount < apiInstances.count - 1 {
            switchToNextInstance()
            performAudioURLRequest(videoId: videoId, retryCount: retryCount + 1, completion: completion)
        } else {
            completion(nil)
        }
    }
}

// MARK: - Вспомогательные структуры ответов API Invidious
struct InvidiousSearchResult: Codable {
    let videoId: String
    let title: String
    let author: String
    let lengthSeconds: Int
}

struct InvidiousVideoInfo: Codable {
    let adaptiveFormats: [InvidiousFormat]
}

struct InvidiousFormat: Codable {
    let url: String
    let mimeType: String
    let bitrate: String?
}
