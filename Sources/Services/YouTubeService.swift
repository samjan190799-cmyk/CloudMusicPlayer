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

enum ChartRegion: String, CaseIterable, Identifiable {
    case russia = "RU"
    case global = "Global"
    case usa = "US"
    case tiktok = "TikTok"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .russia: return "🇷🇺 Россия & СНГ"
        case .global: return "🌍 Global 50"
        case .usa: return "🇺🇸 USA Hits"
        case .tiktok: return "🔥 TikTok Тренды"
        }
    }
    
    var searchQuery: String {
        switch self {
        case .russia: return "Официальный трек клип слушать 2026 -сборник -mix -playlist"
        case .global: return "Official song audio track 2026 -compilation -mix -playlist"
        case .usa: return "Billboard hot 100 official audio song -compilation -mix -playlist"
        case .tiktok: return "TikTok трек слушать 2026 -сборник -mix -playlist"
        }
    }
    
    var regionCode: String {
        switch self {
        case .russia: return "RU"
        case .global: return "US"
        case .usa: return "US"
        case .tiktok: return "RU"
        }
    }
}


/// Сервис для работы с YouTube Music и быстрой выгрузкой аудиопотоков.
class YouTubeService: ObservableObject {
    static let shared = YouTubeService()

    @Published var tracks: [YouTubeTrack] = []
    @Published var trendingTracks: [YouTubeTrack] = []
    @Published var categoryTracks: [YouTubeTrack] = []
    @Published var podcastTracks: [YouTubeTrack] = []
    @Published var audiobookTracks: [YouTubeTrack] = []
    @Published var selectedRegion: ChartRegion = .russia
    @Published var isLoading = false
    @Published var isTrendingLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = false


    private var currentQuery = ""
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?
    private var trendingTask: Task<Void, Never>?

    // Кэш прямых аудиопотоков (videoId -> (URL, Date))
    private var streamCache: [String: (url: URL, date: Date)] = [:]
    private let cacheLock = NSLock()
    private let streamTTL: TimeInterval = 4 * 3600 // 4 часа

    // Список проверенных Invidious-инстансов
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

    private init() {
        // Автоматически загружаем Чарты при старте
        fetchTrendingMusic(region: .russia)
    }

    // MARK: - Кеширование Аудиопотоков

    private func getCachedAudioURL(for videoId: String) -> URL? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let entry = streamCache[videoId] {
            if Date().timeIntervalSince(entry.date) < streamTTL {
                return entry.url
            } else {
                streamCache.removeValue(forKey: videoId)
            }
        }
        return nil
    }

    private func setCachedAudioURL(_ url: URL, for videoId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        streamCache[videoId] = (url, Date())
    }

    // MARK: - Быстрое Извлечение Аудиопотока (0.3 - 0.8 сек)

    /// Извлечение ссылки с кешированием и параллельной гонкой эндпоинтов
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        // 1. Проверка кеша
        if let cached = getCachedAudioURL(for: videoId) {
            print("YouTubeService: ⚡ Мгновенно извлечено из кеша: \(videoId)")
            completion(cached)
            return
        }

        Task {
            // 2. Параллельная гонка между YouTubeKit и Invidious API
            let resolvedURL: URL? = await withTaskGroup(of: URL?.self) { group -> URL? in
                // Таск 1: Извлечение через YouTubeKit
                group.addTask {
                    do {
                        let video = YouTube(videoID: videoId)
                        let streams = try await video.streams
                        let audioOnly = streams.filterAudioOnly()
                        
                        if let m4a = audioOnly.filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream() {
                            return m4a.url
                        }
                        if let mp4 = audioOnly.filter({ $0.fileExtension == .mp4 }).highestAudioBitrateStream() {
                            return mp4.url
                        }
                        if let any = audioOnly.highestAudioBitrateStream() {
                            return any.url
                        }
                        let combined = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }
                        return combined.first?.url
                    } catch {
                        return nil
                    }
                }

                // Таск 2: Извлечение через Invidious Streams API
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return await self.fetchAudioFromInvidious(videoId: videoId)
                }

                // Возвращаем результат от первого успешно ответившего таска
                for await url in group {
                    if let u = url {
                        group.cancelAll()
                        return u
                    }
                }
                return nil
            }

            if let finalURL = resolvedURL {
                self.setCachedAudioURL(finalURL, for: videoId)
                print("YouTubeService: ✅ Извлечен аудио URL: \(videoId)")
                completion(finalURL)
            } else {
                print("YouTubeService: ❌ Ошибка извлечения audio URL для \(videoId)")
                completion(nil)
            }
        }
    }

    private func fetchAudioFromInvidious(videoId: String) async -> URL? {
        // 1. Попытка через Piped API
        let pipedInstances = [
            "https://pipedapi.kavin.rocks",
            "https://api.piped.yt",
            "https://pipedapi.astral.cool",
            "https://pipedapi.drgns.space"
        ]
        
        let pipedResult: URL? = await withTaskGroup(of: URL?.self) { group -> URL? in
            for instance in pipedInstances {
                group.addTask {
                    let urlStr = "\(instance)/streams/\(videoId)"
                    guard let url = URL(string: urlStr) else { return nil }
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 2.0
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let audioStreams = json["audioStreams"] as? [[String: Any]] {
                            for stream in audioStreams {
                                if let urlString = stream["url"] as? String, let audioURL = URL(string: urlString) {
                                    return audioURL
                                }
                            }
                        }
                    } catch {
                        return nil
                    }
                    return nil
                }
            }
            for await url in group {
                if let u = url {
                    group.cancelAll()
                    return u
                }
            }
            return nil
        }
        
        if let pipedResult = pipedResult {
            return pipedResult
        }
        
        // 2. Вторичная попытка через Invidious API и прямого аудио-прокси (/latest_version?id=...&itag=140)
        return await withTaskGroup(of: URL?.self) { group -> URL? in
            for instance in self.apiInstances.shuffled().prefix(4) {
                group.addTask {
                    let proxyStr = "\(instance)/latest_version?id=\(videoId)&itag=140"
                    if let proxyURL = URL(string: proxyStr) {
                        var headReq = URLRequest(url: proxyURL)
                        headReq.httpMethod = "HEAD"
                        headReq.timeoutInterval = 1.8
                        if let (_, resp) = try? await URLSession.shared.data(for: headReq),
                           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 || httpResp.statusCode == 302 {
                            return proxyURL
                        }
                    }
                    
                    let urlStr = "\(instance)/api/v1/videos/\(videoId)"
                    guard let url = URL(string: urlStr) else { return nil }
                    do {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 2.0
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let adaptiveFormats = json["adaptiveFormats"] as? [[String: Any]] {
                            for format in adaptiveFormats {
                                if let type = format["type"] as? String, type.contains("audio"),
                                   let urlString = format["url"] as? String,
                                   let audioURL = URL(string: urlString) {
                                    return audioURL
                                }
                            }
                        }
                    } catch {
                        return nil
                    }
                    return nil
                }
            }
            
            for await url in group {
                if let u = url {
                    group.cancelAll()
                    return u
                }
            }
            return nil
        }
    }



    // MARK: - Валидация Музыкального Контента (Строгая Фильтрация)

    private func isMusicTrack(_ item: InvidiousSearchResult) -> Bool {
        // 1. Фильтр длительности: только песни от 50 секунд до 8 минут (480 сек)
        guard item.lengthSeconds >= 50 && item.lengthSeconds <= 480 else { return false }
        
        let title = item.title.lowercased()
        let author = item.author.lowercased()
        
        // 2. Черный список ключевых слов (игры, киберспорт, проповеди, комедии, подкасты, стримы)
        let forbiddenKeywords = [
            "cs:go", "cs2", "blast", "gameplay", "walkthrough", "lets play", "let's play",
            "gaming", "rust", "pubg", "dota", "dota 2", "minecraft", "apex", "valorant",
            "league of legends", "fortnite", "genshin", "gta", "tournament", "major",
            "qualifier", "podcast", "sermon", "news", "full stream", "live stream",
            "episode", "ep.", "highlights", "reaction", "review", "vlog", "movie",
            "film", "trailer", "asmr", "interview", "documentary", "tutorial", "lesson",
            "preaching", "prayer", "command your morning", "day 1", "day 2", "day 3",
            "streamer", "twitch", "match", "vs", "versus", "comedy", "show", "talk"
        ]
        
        for keyword in forbiddenKeywords {
            if title.contains(keyword) || author.contains(keyword) {
                return false
            }
        }
        
        return true
    }

    /// Строгая фильтрация ТОЛЬКО сольных треков для Чартов (исключает 1-часовые сборки, миксы, топы)
    private func isSingleSongTrack(_ item: InvidiousSearchResult) -> Bool {
        // 1. Длительность одиночной песни: от 70 секунд до 360 секунд (6 минут max)
        guard item.lengthSeconds >= 70 && item.lengthSeconds <= 360 else { return false }
        
        let title = item.title.lowercased()
        let author = item.author.lowercased()
        
        // 2. Исключение сборок, миксов, подборок "Top 50", "Compilation"
        let compilationKeywords = [
            "top 50", "top 100", "top 20", "top 10", "top 30", "top 40",
            "top songs", "best songs", "best of", "compilation", "сборник",
            "микс", "mix", "megamix", "плейлист", "playlist", "full album",
            "full audio", "greatest hits", "discography", "дискография",
            "хиты 20", "песни 20", "mashup", "reverb", "speed up"
        ]
        
        for keyword in compilationKeywords {
            if title.contains(keyword) || author.contains(keyword) {
                return false
            }
        }
        
        return isMusicTrack(item)
    }

    // MARK: - Локальные Чарты & Тренды YouTube Music

    func fetchTrendingMusic(region: ChartRegion? = nil) {
        let currentRegion = region ?? selectedRegion
        self.selectedRegion = currentRegion

        trendingTask?.cancel()
        DispatchQueue.main.async { self.isTrendingLoading = true }

        trendingTask = Task { [weak self] in
            guard let self else { return }
            
            // 1. Пробуем получить официальный трендовый чарт с фильтрацией сольных треков
            var results: [InvidiousSearchResult]? = nil
            for instance in self.apiInstances.shuffled().prefix(3) {
                let urlStr = "\(instance)/api/v1/trending?type=music&region=\(currentRegion.regionCode)"
                guard let url = URL(string: urlStr) else { continue }
                if let raw = await self.fetchResults(url: url) {
                    let filtered = raw.filter { self.isSingleSongTrack($0) }
                    if !filtered.isEmpty {
                        results = filtered
                        break
                    }
                }
            }

            // 2. Если тренды пустые или содержат мало сольных песен, запрашиваем отфильтрованный музыкальный чарт
            if results == nil || (results?.count ?? 0) < 5 {
                if let searchResults = await self.searchRaw(query: currentRegion.searchQuery, page: 1) {
                    results = searchResults.filter { self.isSingleSongTrack($0) }
                }
            }


            guard let items = results, !items.isEmpty else {
                DispatchQueue.main.async { self.isTrendingLoading = false }
                return
            }

            let trending = items.map { item in
                YouTubeTrack(
                    id: item.videoId,
                    title: item.title,
                    uploader: item.author,
                    duration: item.lengthSeconds,
                    thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
                )
            }

            await MainActor.run {
                self.trendingTracks = trending
                self.isTrendingLoading = false
            }
        }
    }


    /// Загрузка музыки по категориям (Pop, Hip-Hop, Electronic, Rock, Chill, Workout)
    func fetchCategoryMusic(genre: String) {
        DispatchQueue.main.async { self.isLoading = true }

        Task { [weak self] in
            guard let self else { return }
            let query = "\(genre) Top Music Songs Hits"
            let rawResults = await self.searchRaw(query: query, page: 1)

            await MainActor.run {
                self.isLoading = false
                guard let items = rawResults else { return }
                let filtered = items.filter { self.isMusicTrack($0) }
                self.categoryTracks = filtered.map { item in
                    YouTubeTrack(
                        id: item.videoId,
                        title: item.title,
                        uploader: item.author,
                        duration: item.lengthSeconds,
                        thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
                    )
                }
            }
        }
    }

    // MARK: - Загрузка Подкастов и Аудиокниг

    /// Загрузка Подкастов (Психология, IT, История, Бизнес, Развлечения)
    func fetchPodcasts(category: String = "Популярные") {
        DispatchQueue.main.async { self.isLoading = true }
        Task { [weak self] in
            guard let self else { return }
            let query = "Подкаст \(category) 2026 выпуск"
            let rawResults = await self.searchRaw(query: query, page: 1)

            await MainActor.run {
                self.isLoading = false
                guard let items = rawResults else { return }
                // Подкасты имеют хронометраж от 5 минут до 3 часов (300с - 10800с)
                let podcasts = items.filter { item in
                    item.lengthSeconds >= 240 && item.lengthSeconds <= 10800
                }.map { item in
                    YouTubeTrack(
                        id: item.videoId,
                        title: item.title,
                        uploader: item.author,
                        duration: item.lengthSeconds,
                        thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
                    )
                }
                self.podcastTracks = podcasts
            }
        }
    }

    /// Загрузка Аудиокниг (Бестселлеры, Фантастика, Саморазвитие, Классика)
    func fetchAudiobooks(category: String = "Бестселлеры") {
        DispatchQueue.main.async { self.isLoading = true }
        Task { [weak self] in
            guard let self else { return }
            let query = "Аудиокнига \(category) слушать полностью"
            let rawResults = await self.searchRaw(query: query, page: 1)

            await MainActor.run {
                self.isLoading = false
                guard let items = rawResults else { return }
                // Аудиокниги обычно от 10 минут до 6 часов (600с - 21600с)
                let books = items.filter { item in
                    item.lengthSeconds >= 480 && item.lengthSeconds <= 21600
                }.map { item in
                    YouTubeTrack(
                        id: item.videoId,
                        title: item.title,
                        uploader: item.author,
                        duration: item.lengthSeconds,
                        thumbnailUrl: "https://img.youtube.com/vi/\(item.videoId)/maxresdefault.jpg"
                    )
                }
                self.audiobookTracks = books
            }
        }
    }

    // MARK: - Обычный Поиск


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

    private func searchRaw(query: String, page: Int) async -> [InvidiousSearchResult]? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return await withTaskGroup(of: [InvidiousSearchResult]?.self) { group -> [InvidiousSearchResult]? in
            for instance in apiInstances.shuffled().prefix(4) {
                let urlStr = "\(instance)/api/v1/search?q=\(encoded)&type=video&page=\(page)"
                guard let url = URL(string: urlStr) else { continue }
                group.addTask { [weak self] () -> [InvidiousSearchResult]? in
                    guard let self else { return nil }
                    return await self.fetchResults(url: url)
                }
            }
            for await result in group {
                if let r = result, !r.isEmpty {
                    group.cancelAll()
                    return r
                }
            }
            return nil
        }
    }

    private func parallelSearch(query: String, page: Int, appending: Bool) async {
        guard !Task.isCancelled else { return }

        let foundResult = await searchRaw(query: query, page: page)
        guard !Task.isCancelled else { return }

        await MainActor.run {
            self.isLoading = false

            guard let items = foundResult, !items.isEmpty else {
                if !appending {
                    self.errorMessage = "Ничего не найдено. Попробуйте другой запрос или проверьте соединение."
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
            request.timeoutInterval = 5
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

    func findMetadata(for query: String, completion: @escaping (YouTubeTrack?) -> Void) {
        Task { [weak self] in
            guard let self else { completion(nil); return }
            let results = await self.searchRaw(query: query, page: 1)
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

