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

/// Сервис для работы с YouTube через Invidious API.
/// Поиск выполняется параллельно по нескольким инстансам — побеждает первый ответивший.
class YouTubeService: ObservableObject {
    static let shared = YouTubeService()

    @Published var tracks: [YouTubeTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = false

    private var currentQuery = ""
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?

    // Список Invidious-инстансов (только для поиска, аудио идёт через YouTubeKit напрямую)
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

    /// Новый поиск — отменяет предыдущий, запускает гонку по всем инстансам
    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        searchTask?.cancel()
        currentQuery = q
        currentPage = 1

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.canLoadMore = false
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.parallelSearch(query: q, page: 1, appending: false)
        }
    }

    /// Подгрузка следующей страницы
    func loadMore() {
        guard !isLoading, !currentQuery.isEmpty, canLoadMore else { return }
        let nextPage = currentPage + 1
        let query = currentQuery

        DispatchQueue.main.async { self.isLoading = true }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.parallelSearch(query: query, page: nextPage, appending: true)
        }
    }

    // MARK: - Параллельный поиск

    private func parallelSearch(query: String, page: Int, appending: Bool) async {
        guard !Task.isCancelled else { return }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var firstResult: [InvidiousSearchResult]? = nil

        await withTaskGroup(of: [InvidiousSearchResult]?.self) { group in
            for instance in apiInstances {
                let urlStr = "\(instance)/api/v1/search?q=\(encoded)&type=video&page=\(page)"
                guard let url = URL(string: urlStr) else { continue }
                group.addTask { [weak self] () -> [InvidiousSearchResult]? in
                    guard let self, !Task.isCancelled else { return nil }
                    return await self.fetchResults(url: url)
                }
            }

            for await result in group {
                if let r = result, !r.isEmpty, firstResult == nil {
                    firstResult = r
                    group.cancelAll()
                    break
                }
            }
        }

        guard !Task.isCancelled else { return }

        await MainActor.run {
            self.isLoading = false

            guard let items = firstResult, !items.isEmpty else {
                if !appending {
                    self.errorMessage = "Ничего не найдено. Попробуйте другой запрос или проверьте интернет."
                }
                self.canLoadMore = false
                return
            }

            let newTracks = items.map { item in
                YouTubeTrack(
                    id: item.videoId,
                    title: item.title,
                    uploader: item.author,
                    duration: item.lengthSeconds,
                    thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
                )
            }

            if appending {
                self.tracks.append(contentsOf: newTracks)
            } else {
                self.tracks = newTracks
            }

            self.currentPage = page
            self.canLoadMore = newTracks.count >= 15
            self.errorMessage = nil
        }
    }

    private func fetchResults(url: URL) async -> [InvidiousSearchResult]? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6
            request.setValue("CloudMusicPlayer/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            return try? JSONDecoder().decode([InvidiousSearchResult].self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Поиск метаданных (для DownloadManager)

    func findMetadata(for query: String, completion: @escaping (YouTubeTrack?) -> Void) {
        Task { [weak self] in
            guard let self else { completion(nil); return }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            var firstResult: [InvidiousSearchResult]? = nil

            await withTaskGroup(of: [InvidiousSearchResult]?.self) { group in
                for instance in self.apiInstances {
                    let urlStr = "\(instance)/api/v1/search?q=\(encoded)&type=video&page=1"
                    guard let url = URL(string: urlStr) else { continue }
                    group.addTask { [weak self] () -> [InvidiousSearchResult]? in
                        guard let self else { return nil }
                        return await self.fetchResults(url: url)
                    }
                }
                for await result in group {
                    if let r = result, !r.isEmpty, firstResult == nil {
                        firstResult = r
                        group.cancelAll()
                        break
                    }
                }
            }

            guard let first = firstResult?.first else {
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

    // MARK: - Аудиопоток через YouTubeKit

    /// Извлечение прямой ссылки на аудиопоток по videoId.
    /// YouTubeKit работает напрямую с серверами YouTube — API ключи не нужны.
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                let video = YouTube(videoID: videoId)
                let streams = try await video.streams

                // Приоритет 1: M4A (лучшая совместимость с AVPlayer)
                let audioOnly = streams.filterAudioOnly()
                if let m4a = audioOnly.filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream() {
                    completion(m4a.url); return
                }

                // Приоритет 2: MP4-аудио
                if let mp4 = audioOnly.filter({ $0.fileExtension == .mp4 }).highestAudioBitrateStream() {
                    completion(mp4.url); return
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

    /// Видеопоток (для превью-кадров)
    func getVideoURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                let video = YouTube(videoID: videoId)
                let streams = try await video.streams
                let combined = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }
                completion(combined.first?.url)
            } catch {
                completion(nil)
            }
        }
    }
}

// MARK: - Модель ответа Invidious API

struct InvidiousSearchResult: Codable {
    let videoId: String
    let title: String
    let author: String
    let lengthSeconds: Int
}
