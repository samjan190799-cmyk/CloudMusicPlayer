import Foundation
import YouTubeKit

/// Модель трека с YouTube
struct YouTubeTrack: Identifiable, Codable {
    let id: String          // videoId
    let title: String
    let uploader: String
    let duration: Int       // В секундах
    let thumbnailUrl: String
}

/// Сервис для работы с YouTube через Invidious API
/// Поиск выполняется параллельно по нескольким инстансам — побеждает тот, кто ответил первым.
class YouTubeService: ObservableObject {
    static let shared = YouTubeService()

    @Published var tracks: [YouTubeTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = false

    private var currentQuery = ""
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?

    // MARK: - Список инстансов Invidious (публичные, проверены)
    // Примечание: используются ТОЛЬКО для поиска видео.
    // Получение аудиопотоков выполняется через YouTubeKit напрямую.
    private let apiInstances = [
        "https://inv.nadeko.net",
        "https://yewtu.be",
        "https://invidious.nerdvpn.de",
        "https://invidious.f5.si",
        "https://invidious.tiekoetter.com",
        "https://yt.chocolatemoo53.com",
        "https://inv.zoomerville.com",
        "https://vid.puffyan.us",
        "https://invidious.privacydev.net"
    ]

    private init() {}

    // MARK: - Публичный API

    /// Поиск треков — запускает гонку по всем инстансам одновременно
    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        searchTask?.cancel()
        currentQuery = q
        currentPage = 1
        canLoadMore = false
        errorMessage = nil

        DispatchQueue.main.async { self.isLoading = true }

        searchTask = Task {
            await performParallelSearch(query: q, page: 1, appending: false)
        }
    }

    /// Подгрузка следующей страницы
    func loadMore() {
        guard !isLoading, !currentQuery.isEmpty, canLoadMore else { return }
        let nextPage = currentPage + 1

        DispatchQueue.main.async { self.isLoading = true }

        searchTask?.cancel()
        searchTask = Task {
            await performParallelSearch(query: currentQuery, page: nextPage, appending: true)
        }
    }

    // MARK: - Параллельный поиск (race between instances)

    @MainActor
    private func performParallelSearch(query: String, page: Int, appending: Bool) async {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        // Запросы к каждому инстансу конкурируют. Добавляем параметр music — фильтр тематики
        let results = await withTaskGroup(of: [InvidiousSearchResult]?.self) { group in
            for instance in apiInstances {
                let urlStr = "\(instance)/api/v1/search?q=\(encoded)&type=video&page=\(page)"
                guard let url = URL(string: urlStr) else { continue }

                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return await self.fetchSearchResults(from: url)
                }
            }

            // Возвращаем первый непустой ответ
            for await result in group {
                if let r = result, !r.isEmpty {
                    group.cancelAll()
                    return r
                }
            }
            return nil
        }

        isLoading = false

        guard let items = results, !items.isEmpty else {
            if !appending {
                errorMessage = "Ничего не найдено. Попробуйте другой запрос или проверьте интернет."
            }
            canLoadMore = false
            return
        }

        let newTracks = items.map { item in
            YouTubeTrack(
                id: item.videoId,
                title: item.title,
                uploader: item.author,
                duration: item.lengthSeconds,
                // Цепочка качества: maxres → hq → mq (loadable fallback в View)
                thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
            )
        }

        if appending {
            tracks.append(contentsOf: newTracks)
        } else {
            tracks = newTracks
        }

        currentPage = page
        // YouTube возвращает до 20 результатов на страницу
        canLoadMore = newTracks.count >= 15
        errorMessage = nil
    }

    private func fetchSearchResults(from url: URL) async -> [InvidiousSearchResult]? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6 // Таймаут 6 секунд — быстро отсекаем медленные инстансы
            request.setValue("CloudMusicPlayer/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            return try JSONDecoder().decode([InvidiousSearchResult].self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Поиск метаданных (для DownloadManager)

    func findMetadata(for query: String, completion: @escaping (YouTubeTrack?) -> Void) {
        Task {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let results = await withTaskGroup(of: [InvidiousSearchResult]?.self) { group in
                for instance in apiInstances {
                    let urlStr = "\(instance)/api/v1/search?q=\(encoded)&type=video&page=1"
                    guard let url = URL(string: urlStr) else { continue }
                    group.addTask { [weak self] in await self?.fetchSearchResults(from: url) }
                }
                for await result in group {
                    if let r = result, !r.isEmpty { group.cancelAll(); return r }
                }
                return nil
            }

            guard let first = results?.first else {
                completion(nil)
                return
            }

            let track = YouTubeTrack(
                id: first.videoId,
                title: first.title,
                uploader: first.author,
                duration: first.lengthSeconds,
                thumbnailUrl: "https://img.youtube.com/vi/\(first.videoId)/maxresdefault.jpg"
            )
            completion(track)
        }
    }

    // MARK: - Извлечение аудиопотока через YouTubeKit

    /// Получение прямой ссылки на аудиопоток по ID видео.
    /// YouTubeKit — нативная Swift-библиотека, извлекает URL напрямую с серверов YouTube
    /// без посредников. API ключи здесь НЕ нужны — всё работает через открытый YouTube API.
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                let video = YouTube(videoID: videoId, methods: [.remote, .local])
                let streams = try await video.streams

                // Приоритет 1: M4A (AAC) — лучшая совместимость с AVPlayer
                let audioOnly = streams.filterAudioOnly()
                let m4a = audioOnly.filter { $0.fileExtension == .m4a }
                if let best = m4a.highestAudioBitrateStream() {
                    completion(best.url); return
                }

                // Приоритет 2: MP4-аудио
                let mp4audio = audioOnly.filter { $0.fileExtension == .mp4 }
                if let best = mp4audio.highestAudioBitrateStream() {
                    completion(best.url); return
                }

                // Приоритет 3: Любой аудиопоток
                if let any = audioOnly.highestAudioBitrateStream() {
                    completion(any.url); return
                }

                // Приоритет 4: Комбинированный MP4
                let combined = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }
                if let fallback = combined.first {
                    completion(fallback.url); return
                }

                completion(nil)
            } catch {
                print("YouTubeKit error [\(videoId)]: \(error)")
                completion(nil)
            }
        }
    }

    /// Получение видеопотока (для превью кадров)
    func getVideoURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                let video = YouTube(videoID: videoId, methods: [.remote, .local])
                let streams = try await video.streams
                let combined = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }
                completion(combined.first?.url)
            } catch {
                completion(nil)
            }
        }
    }
}

// MARK: - Модель ответа Invidious

struct InvidiousSearchResult: Codable {
    let videoId: String
    let title: String
    let author: String
    let lengthSeconds: Int
}
