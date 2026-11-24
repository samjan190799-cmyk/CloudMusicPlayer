import Foundation
import Combine
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
        case .global: return "Billboard hot 100 official audio song 2026 -compilation -mix -playlist"
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

/// Сервис для работы с YouTube Music на нативном движке YouTubeKit (InnerTube)
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

    // Песни из каталога YouTube Music (поиск с фильтром «Песни»)
    @Published var songs: [YouTubeTrack] = []
    @Published var isSongsLoading = false
    @Published var canLoadMoreSongs = false

    private var currentQuery = ""
    private var currentPage = 1
    private var continuationToken: String? = nil
    private var searchTask: Task<Void, Never>?
    private var trendingTask: Task<Void, Never>?
    private var songsQuery = ""
    private var songsContinuation: String? = nil
    private var songsTask: Task<Void, Never>?

    // Метаданные известных треков (videoId -> трек), защищено cacheLock.
    // Нужны, чтобы найти другую загрузку той же песни, если YouTube не отдал поток.
    private var knownTracks: [String: YouTubeTrack] = [:]
    // Ссылки резервного клиента: AVPlayer не открывает их напрямую, их нужно сначала скачать (защищено cacheLock)
    private var downloadBeforePlaybackURLs: Set<URL> = []

    // Кэш прямых аудиопотоков (videoId -> (URL, Date))
    private var streamCache: [String: (url: URL, date: Date)] = [:]
    private let cacheLock = NSLock()
    private let streamTTL: TimeInterval = 3600 // 1 час (ссылки googlevideo живут от 2 до 6 часов)
    // Ожидающие завершения извлечения (videoId -> колбэки), защищено cacheLock
    private var pendingAudioRequests: [String: [(URL?) -> Void]] = [:]
    // Последняя причина отказа YouTube по videoId (для диагностики и смоук-теста), защищено cacheLock
    private var extractionFailureReasons: [String: String] = [:]

    /// Причина, по которой YouTube не отдал поток (например, «Sign in to confirm you’re not a bot»)
    func lastExtractionFailureReason(for videoId: String) -> String? {
        cacheLock.withLock { extractionFailureReasons[videoId] }
    }

    private init() {
        // Автоматически загружаем Чарты при старте приложения
        fetchTrendingMusic(region: .russia)
    }

    // MARK: - Кэширование Аудиопотоков

    func invalidateStreamCache(for videoId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        streamCache.removeValue(forKey: videoId)
        print("YouTubeService: 🔄 Кэш аудиопотока сброшен для \(videoId)")
    }

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

    // MARK: - Нативное Извлечение Аудиопотока через YouTubeKit (InnerTube)

    /// Получение прямого потока через нативный YouTubeKit с приоритетом на M4A / AAC (itag 140).
    /// Одновременные запросы одного videoId (плеер, кэш, предзагрузка) объединяются в одно извлечение.
    func getAudioURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        // 1. Проверка локального кэша
        if let cached = getCachedAudioURL(for: videoId) {
            print("YouTubeService: ⚡ Мгновенно извлечено из кэша: \(videoId)")
            completion(cached)
            return
        }

        // 2. Если извлечение уже идёт — просто ждём его результата
        let isAlreadyRunning: Bool = cacheLock.withLock {
            if pendingAudioRequests[videoId] != nil {
                pendingAudioRequests[videoId]?.append(completion)
                return true
            }
            pendingAudioRequests[videoId] = [completion]
            return false
        }
        if isAlreadyRunning { return }

        Task {
            // 1. YouTubeKit, затем прямой запрос плеера InnerTube
            var resolvedURL = await self.resolveStreamURL(for: videoId)

            // 2. Видео недоступно (например, официальный клип лейбла) — пробуем другую
            //    загрузку той же песни из каталога YouTube Music
            if resolvedURL == nil {
                resolvedURL = await self.alternateUploadURL(for: videoId)
            }

            if let finalURL = resolvedURL {
                self.setCachedAudioURL(finalURL, for: videoId)
            } else {
                print("YouTubeService: ❌ Не удалось извлечь аудио URL для \(videoId)")
            }

            let waiters = self.cacheLock.withLock {
                self.pendingAudioRequests.removeValue(forKey: videoId) ?? []
            }
            waiters.forEach { $0(resolvedURL) }
        }
    }

    /// Одна попытка извлечения с гарантированным таймаутом: результат отдаётся тем, кто успел первым
    /// (YouTubeKit может не реагировать на отмену, поэтому не ждём его внутри task group)
    private func extractAudioURL(for videoId: String, timeout: TimeInterval) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            let gate = ResumeGate(continuation)

            let extraction = Task {
                do {
                    let streams = try await YouTube(videoID: videoId).streams
                    gate.resume(with: YouTubeService.bestAudioStreamURL(from: streams))
                } catch {
                    print("YouTubeService: Ошибка YouTubeKit streams: \(error)")
                    gate.resume(with: nil)
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if gate.resume(with: nil) {
                    print("YouTubeService: ⏱ Таймаут извлечения потока \(videoId)")
                    extraction.cancel()
                }
            }
        }
    }

    /// Потокобезопасно возобновляет continuation ровно один раз
    private final class ResumeGate: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL?, Never>?

        init(_ continuation: CheckedContinuation<URL?, Never>) {
            self.continuation = continuation
        }

        /// - Returns: `true`, если именно этот вызов возобновил continuation
        @discardableResult
        func resume(with url: URL?) -> Bool {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(returning: url)
            return pending != nil
        }
    }

    // MARK: - Резервное извлечение через InnerTube /player

    private struct PlayerClient {
        let name: String
        let id: Int
        let version: String
        let userAgent: String
        let extraContext: [String: Any]
    }

    /// Клиенты, которым YouTube отдаёт прямые ссылки без шифрования подписи и без PO-токена
    private static let fallbackPlayerClients: [PlayerClient] = [
        PlayerClient(
            name: "ANDROID_VR",
            id: 28,
            version: "1.65.10",
            userAgent: "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
            extraContext: ["androidSdkVersion": 32, "deviceMake": "Oculus", "deviceModel": "Quest 3", "osName": "Android", "osVersion": "12L"]
        ),
        PlayerClient(
            name: "IOS",
            id: 5,
            version: "20.10.4",
            userAgent: "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
            extraContext: ["deviceMake": "Apple", "deviceModel": "iPhone16,2", "osName": "iPhone", "osVersion": "18.3.2.22D82"]
        )
    ]

    private func fetchAudioURLViaInnerTubePlayer(videoId: String) async -> URL? {
        for client in Self.fallbackPlayerClients {
            if let url = await requestPlayer(videoId: videoId, client: client) {
                print("YouTubeService: ✅ Аудио URL через InnerTube \(client.name): \(videoId)")
                cacheLock.withLock { _ = downloadBeforePlaybackURLs.insert(url) }
                return url
            }
        }
        return nil
    }

    /// Ссылку нельзя отдать AVPlayer как поток — сначала скачать файл целиком (см. смоук-тест)
    func requiresDownloadBeforePlayback(_ url: URL) -> Bool {
        cacheLock.withLock { downloadBeforePlaybackURLs.contains(url) }
    }

    /// Прямой запрос плеера InnerTube в обход YouTubeKit (для смоук-теста)
    func fallbackAudioURL(for videoId: String) async -> URL? {
        await fetchAudioURLViaInnerTubePlayer(videoId: videoId)
    }

    private func requestPlayer(videoId: String, client: PlayerClient) async -> URL? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else { return nil }

        var clientContext: [String: Any] = [
            "clientName": client.name,
            "clientVersion": client.version,
            "hl": "en",
            "gl": "US"
        ]
        clientContext.merge(client.extraContext) { current, _ in current }

        let payload: [String: Any] = [
            "context": ["client": clientContext],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(String(client.id), forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let visitorData = UserDefaults.standard.string(forKey: "com.samvel.cloudmusicplayer.visitorData") {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("YouTubeService: InnerTube \(client.name) HTTP \(status) для \(videoId)")
                return nil
            }

            let playability = root["playabilityStatus"] as? [String: Any]
            let playabilityStatus = playability?["status"] as? String ?? "?"
            guard playabilityStatus == "OK" else {
                let reason = playability?["reason"] as? String ?? ""
                print("YouTubeService: InnerTube \(client.name) → \(playabilityStatus) \(reason) для \(videoId)")
                cacheLock.withLock { extractionFailureReasons[videoId] = "\(playabilityStatus): \(reason)" }
                return nil
            }

            if let details = root["videoDetails"] as? [String: Any],
               let returnedId = details["videoId"] as? String, returnedId != videoId {
                print("YouTubeService: InnerTube \(client.name) вернул чужое видео \(returnedId)")
                return nil
            }

            guard let streaming = root["streamingData"] as? [String: Any] else {
                print("YouTubeService: InnerTube \(client.name) без streamingData для \(videoId)")
                return nil
            }

            return Self.bestDirectAudioURL(from: streaming)
        } catch {
            print("YouTubeService: InnerTube \(client.name) ошибка: \(error.localizedDescription)")
            return nil
        }
    }

    /// Лучший AAC-поток (audio/mp4) с прямой ссылкой; иначе прогрессивный MP4 (itag 18)
    private static func bestDirectAudioURL(from streaming: [String: Any]) -> URL? {
        let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] ?? []
        let audioMP4 = adaptive
            .filter { ($0["mimeType"] as? String)?.hasPrefix("audio/mp4") == true && $0["url"] is String }
            .filter { format in
                // Пропускаем дублированные/автопереведённые дорожки, если YouTube их помечает
                guard let track = format["audioTrack"] as? [String: Any] else { return true }
                return (track["audioIsDefault"] as? Bool) ?? true
            }
            .sorted { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }
        if let best = audioMP4.first, let urlString = best["url"] as? String {
            return URL(string: urlString)
        }

        let progressive = streaming["formats"] as? [[String: Any]] ?? []
        if let mp4 = progressive.first(where: { ($0["mimeType"] as? String)?.hasPrefix("video/mp4") == true && $0["url"] is String }),
           let urlString = mp4["url"] as? String {
            return URL(string: urlString)
        }
        return nil
    }

    private static func bestAudioStreamURL(from streams: [YouTubeKit.Stream]) -> URL? {
        let audioOnly = streams.filterAudioOnly()
        let playableOnly = audioOnly.filter { $0.isNativelyPlayable }

        // 1. Нативный M4A с максимальным битрейтом (itag 140 / 128 kbps AAC)
        if let m4a = playableOnly.filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream() {
            return m4a.url
        }
        // 2. Любой нативно воспроизводимый аудиопоток
        if let anyPlayable = playableOnly.highestAudioBitrateStream() {
            return anyPlayable.url
        }
        // 3. Комбинированный аудио+видео MP4 поток как крайний вариант (AVPlayer играет его звук)
        let combined = streams.filterVideoAndAudio().filter { $0.isNativelyPlayable && $0.fileExtension == .mp4 }
        return combined.lowestResolutionStream()?.url ?? combined.first?.url
    }

    /// Получение прямого видеопотока для захвата обложки или предварительного просмотра
    func getVideoURL(for videoId: String, completion: @escaping (URL?) -> Void) {
        Task {
            do {
                let video = YouTube(videoID: videoId)
                let streams = try await video.streams
                let mp4 = streams.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }.first
                    ?? streams.filterVideoOnly().filter { $0.fileExtension == .mp4 }.first
                completion(mp4?.url)
            } catch {
                print("YouTubeService: Ошибка получения видеопотока: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - Валидация Музыкального Контента (Фильтрация шума)

    private func isMusicTrack(_ item: YouTubeTrack) -> Bool {
        // 1. Фильтр длительности: только треки от 40 секунд до 12 минут (720 сек)
        guard item.duration >= 40 && item.duration <= 720 else { return false }
        
        let title = item.title.lowercased()
        let author = item.uploader.lowercased()
        
        // 2. Черный список ключевых слов (игры, киберспорт, проповеди, комедии, стримы)
        let forbiddenKeywords = [
            "cs:go", "cs2", "blast", "gameplay", "walkthrough", "lets play", "let's play",
            "gaming", "rust", "pubg", "dota", "dota 2", "minecraft", "apex", "valorant",
            "league of legends", "fortnite", "genshin", "gta", "tournament", "major",
            "qualifier", "podcast", "sermon", "news", "full stream", "live stream",
            "episode", "ep.", "highlights", "reaction", "review", "vlog", "movie",
            "film", "trailer", "asmr", "interview", "documentary", "tutorial", "lesson",
            "preaching", "prayer", "command your morning", "day 1", "day 2", "day 3",
            "streamer", "twitch", "versus", "comedy"
        ]
        
        for keyword in forbiddenKeywords {
            if title.contains(keyword) || author.contains(keyword) {
                return false
            }
        }
        
        return true
    }

    /// Строгая фильтрация ТОЛЬКО сольных треков для Чартов (исключает длинные сборки, миксы, топы)
    private func isSingleSongTrack(_ item: YouTubeTrack) -> Bool {
        // Длительность сольной песни: от 40 секунд до 600 секунд (10 минут max)
        guard item.duration >= 40 && item.duration <= 600 else { return false }
        
        let title = item.title.lowercased()
        let author = item.uploader.lowercased()
        
        // Исключение сборок, миксов, подборок "Top 50", "Compilation", дискографий
        let compilationKeywords = [
            "top 50", "top 100", "top 20", "top 10", "top 30", "top 40",
            "top songs", "best songs", "best of", "compilation", "сборник",
            "megamix", "full album", "full audio", "дискография", "discography",
            "1 hour", "10 hours", "1 hour loop", "10 hours loop"
        ]
        
        for keyword in compilationKeywords {
            if title.contains(keyword) || author.contains(keyword) {
                return false
            }
        }
        
        return isMusicTrack(item)
    }

    // MARK: - Чарты и Тренды

    func fetchTrendingMusic(region: ChartRegion? = nil) {
        let currentRegion = region ?? selectedRegion
        self.selectedRegion = currentRegion

        trendingTask?.cancel()
        DispatchQueue.main.async { self.isTrendingLoading = true }

        trendingTask = Task { [weak self] in
            guard let self else { return }
            
            // Прямой опрос нативного YouTube InnerTube API
            let result = await self.searchInnerTube(query: currentRegion.searchQuery)
            
            await MainActor.run {
                self.isTrendingLoading = false
                guard let items = result?.tracks, !items.isEmpty else { return }
                let filtered = items.filter { self.isSingleSongTrack($0) }
                self.trendingTracks = filtered.isEmpty ? items : filtered
            }
        }
    }

    /// Загрузка музыки по категориям (Pop, Hip-Hop, Electronic, Rock, Chill, Workout)
    func fetchCategoryMusic(genre: String) {
        DispatchQueue.main.async { self.isLoading = true }

        Task { [weak self] in
            guard let self else { return }
            let query = "\(genre) Top Music Songs 2026 -сборник -mix"
            let result = await self.searchInnerTube(query: query)

            await MainActor.run {
                self.isLoading = false
                guard let items = result?.tracks else { return }
                let filtered = items.filter { self.isMusicTrack($0) }
                self.categoryTracks = filtered.isEmpty ? items : filtered
            }
        }
    }

    // MARK: - Подкасты и Аудиокниги

    /// Загрузка Подкастов (Психология, IT, История, Бизнес, Развлечения)
    func fetchPodcasts(category: String = "Популярные") {
        DispatchQueue.main.async { self.isLoading = true }
        Task { [weak self] in
            guard let self else { return }
            let query = "Подкаст \(category) 2026 выпуск"
            let result = await self.searchInnerTube(query: query)

            await MainActor.run {
                self.isLoading = false
                guard let items = result?.tracks else { return }
                // Подкасты имеют хронометраж от 4 минут до 3 часов (240с - 10800с)
                let podcasts = items.filter { $0.duration >= 240 && $0.duration <= 10800 }
                self.podcastTracks = podcasts.isEmpty ? items : podcasts
            }
        }
    }

    /// Загрузка Аудиокниг (Бестселлеры, Фантастика, Саморазвитие, Классика)
    func fetchAudiobooks(category: String = "Бестселлеры") {
        DispatchQueue.main.async { self.isLoading = true }
        Task { [weak self] in
            guard let self else { return }
            let query = "Аудиокнига \(category) слушать полностью"
            let result = await self.searchInnerTube(query: query)

            await MainActor.run {
                self.isLoading = false
                guard let items = result?.tracks else { return }
                // Аудиокниги от 8 минут до 6 часов (480с - 21600с)
                let books = items.filter { $0.duration >= 480 && $0.duration <= 21600 }
                self.audiobookTracks = books.isEmpty ? items : books
            }
        }
    }

    // MARK: - Поиск и Пагинация

    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        searchTask?.cancel()
        currentQuery = q
        currentPage = 1
        continuationToken = nil

        // Параллельно ищем песни в каталоге YouTube Music
        searchSongs(query: q)

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.canLoadMore = false
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            
            if let innerTube = await self.searchInnerTube(query: q) {
                await MainActor.run {
                    self.isLoading = false
                    if !innerTube.tracks.isEmpty {
                        self.tracks = innerTube.tracks
                        self.continuationToken = innerTube.nextToken
                        self.canLoadMore = innerTube.nextToken != nil
                        self.errorMessage = nil
                    } else {
                        self.tracks = []
                        self.canLoadMore = false
                        self.errorMessage = "Ничего не найдено. Попробуйте другой запрос."
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.canLoadMore = false
                    self.errorMessage = "Ошибка подключения к YouTube. Проверьте сеть."
                }
            }
        }
    }

    func loadMore() {
        guard !isLoading, !currentQuery.isEmpty, canLoadMore else { return }
        let query = currentQuery
        let token = continuationToken

        DispatchQueue.main.async { self.isLoading = true }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            
            if let innerTube = await self.searchInnerTube(query: query, continuationToken: token) {
                await MainActor.run {
                    self.isLoading = false
                    // YouTube иногда повторяет видео между страницами — дубликаты ломают ForEach
                    let existing = Set(self.tracks.map(\.id))
                    self.tracks.append(contentsOf: innerTube.tracks.filter { !existing.contains($0.id) })
                    self.continuationToken = innerTube.nextToken
                    self.canLoadMore = innerTube.nextToken != nil
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.canLoadMore = false
                }
            }
        }
    }

    func findMetadata(for query: String, completion: @escaping (YouTubeTrack?) -> Void) {
        Task { [weak self] in
            guard let self else { completion(nil); return }
            let result = await self.searchInnerTube(query: query)
            completion(result?.tracks.first)
        }
    }

    // MARK: - Нативный YouTube InnerTube API клиент

    private func searchInnerTube(query: String, continuationToken: String? = nil) async -> (tracks: [YouTubeTrack], nextToken: String?)? {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 7.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        
        // Поддержание постоянной сессии с visitor data
        if let visitorData = UserDefaults.standard.string(forKey: "com.samvel.cloudmusicplayer.visitorData") {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        
        var payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20260708.00.00",
                    "hl": "ru",
                    "gl": "RU"
                ]
            ]
        ]
        
        if let token = continuationToken {
            payload["continuation"] = token
        } else {
            payload["query"] = query
            payload["params"] = "EgIQAQ==" // Фильтр «Только видео»: без каналов, плейлистов и шортсов-подборок
        }
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return parseInnerTubeResponse(data: data)
        } catch {
            print("YouTubeService: InnerTube error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseInnerTubeResponse(data: Data) -> (tracks: [YouTubeTrack], nextToken: String?)? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        // Сохраняем свежий visitorData для сессии
        if let respContext = root["responseContext"] as? [String: Any],
           let visitorData = respContext["visitorData"] as? String, !visitorData.isEmpty {
            UserDefaults.standard.set(visitorData, forKey: "com.samvel.cloudmusicplayer.visitorData")
        }
        
        var extractedTracks: [YouTubeTrack] = []
        var nextContinuationToken: String? = nil
        
        // 1. Парсинг первого экрана поиска (contents -> twoColumnSearchResultsRenderer)
        if let contents = root["contents"] as? [String: Any],
           let twoCol = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
           let primary = twoCol["primaryContents"] as? [String: Any],
           let sectionList = primary["sectionListRenderer"] as? [String: Any],
           let sections = sectionList["contents"] as? [[String: Any]] {
            
            for section in sections {
                if let itemSection = section["itemSectionRenderer"] as? [String: Any],
                   let items = itemSection["contents"] as? [[String: Any]] {
                    for item in items {
                        if let track = extractTrack(from: item) {
                            extractedTracks.append(track)
                        }
                    }
                }
                
                if let cont = section["continuationItemRenderer"] as? [String: Any],
                   let endpoint = cont["continuationEndpoint"] as? [String: Any],
                   let command = endpoint["continuationCommand"] as? [String: Any],
                   let token = command["token"] as? String {
                    nextContinuationToken = token
                }
            }
        }
        
        // 2. Парсинг страниц пагинации (onResponseReceivedCommands)
        if let commands = root["onResponseReceivedCommands"] as? [[String: Any]] {
            for command in commands {
                if let append = command["appendContinuationItemsAction"] as? [String: Any],
                   let contItems = append["continuationItems"] as? [[String: Any]] {
                    for contItem in contItems {
                        if let itemSection = contItem["itemSectionRenderer"] as? [String: Any],
                           let items = itemSection["contents"] as? [[String: Any]] {
                            for item in items {
                                if let track = extractTrack(from: item) {
                                    extractedTracks.append(track)
                                }
                            }
                        } else if let track = extractTrack(from: contItem) {
                            extractedTracks.append(track)
                        }
                        
                        if let cont = contItem["continuationItemRenderer"] as? [String: Any],
                           let endpoint = cont["continuationEndpoint"] as? [String: Any],
                           let cmd = endpoint["continuationCommand"] as? [String: Any],
                           let token = cmd["token"] as? String {
                            nextContinuationToken = token
                        }
                    }
                }
            }
        }
        
        rememberTracks(extractedTracks)
        return (extractedTracks, nextContinuationToken)
    }
    
    private func extractTrack(from item: [String: Any]) -> YouTubeTrack? {
        guard let v = item["videoRenderer"] as? [String: Any],
              let videoId = v["videoId"] as? String, !videoId.isEmpty else {
            return nil
        }
        
        var title = "YouTube Track"
        if let titleObj = v["title"] as? [String: Any] {
            if let runs = titleObj["runs"] as? [[String: Any]], let first = runs.first, let t = first["text"] as? String {
                title = t
            } else if let simple = titleObj["simpleText"] as? String {
                title = simple
            }
        }
        
        var author = "YouTube"
        let authorObj = (v["ownerText"] as? [String: Any]) ?? (v["longBylineText"] as? [String: Any])
        if let aObj = authorObj, let runs = aObj["runs"] as? [[String: Any]], let first = runs.first, let a = first["text"] as? String {
            author = a
        }
        
        var durationSeconds = 0
        if let lengthObj = v["lengthText"] as? [String: Any], let s = lengthObj["simpleText"] as? String {
            durationSeconds = parseDurationString(s)
        }
        // Прямые эфиры и премьеры без длительности нельзя проиграть как аудиофайл
        guard durationSeconds > 0 else { return nil }
        
        let thumbUrl = "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        
        return YouTubeTrack(
            id: videoId,
            title: title,
            uploader: author,
            duration: durationSeconds,
            thumbnailUrl: thumbUrl
        )
    }
    
    private func parseDurationString(_ string: String) -> Int {
        let parts = string.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":")
        guard !parts.isEmpty else { return 0 }
        
        if parts.count == 3, let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]) {
            return h * 3600 + m * 60 + s
        } else if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
            return m * 60 + s
        } else if parts.count == 1, let s = Int(parts[0]) {
            return s
        }
        return 0
    }
    // MARK: - Поиск песен в каталоге YouTube Music

    /// Фильтр «Песни» поиска YouTube Music (официальные аудиодорожки с исполнителем, альбомом и длительностью)
    private static let musicSongsFilter = "EgWKAQIIAWoKEAoQAxAEEAkQBQ=="
    private static let musicClientVersion = "1.20251110.01.00"

    /// Поиск песен YouTube Music для экрана поиска (результаты — в `songs`)
    func searchSongs(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        songsTask?.cancel()
        songsQuery = q
        songsContinuation = nil

        DispatchQueue.main.async {
            self.isSongsLoading = true
            self.canLoadMoreSongs = false
        }

        songsTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.searchMusicSongs(query: q)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isSongsLoading = false
                self.songs = result?.tracks ?? []
                self.songsContinuation = result?.nextToken
                self.canLoadMoreSongs = result?.nextToken != nil && !(result?.tracks.isEmpty ?? true)
            }
        }
    }

    /// Следующая страница песен
    func loadMoreSongs() {
        guard !isSongsLoading, canLoadMoreSongs, let token = songsContinuation, !songsQuery.isEmpty else { return }
        let query = songsQuery

        DispatchQueue.main.async { self.isSongsLoading = true }

        songsTask?.cancel()
        songsTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.searchMusicSongs(query: query, continuation: token)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isSongsLoading = false
                guard let result = result else {
                    self.canLoadMoreSongs = false
                    return
                }
                let existing = Set(self.songs.map(\.id))
                self.songs.append(contentsOf: result.tracks.filter { !existing.contains($0.id) })
                self.songsContinuation = result.nextToken
                self.canLoadMoreSongs = result.nextToken != nil && !result.tracks.isEmpty
            }
        }
    }

    /// Запрос к поиску YouTube Music с фильтром «Песни». Возвращает nil при сетевой ошибке.
    func searchMusicSongs(query: String, continuation: String? = nil) async -> (tracks: [YouTubeTrack], nextToken: String?)? {
        var urlString = "https://music.youtube.com/youtubei/v1/search?prettyPrint=false"
        if let token = continuation {
            let encoded = Self.encodeQueryValue(token)
            urlString += "&ctoken=\(encoded)&continuation=\(encoded)&type=next"
        }
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        if let visitorData = UserDefaults.standard.string(forKey: "com.samvel.cloudmusicplayer.visitorData") {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": Self.musicClientVersion,
                    "hl": "ru",
                    "gl": "RU"
                ]
            ],
            "query": query,
            "params": Self.musicSongsFilter
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("YouTubeService: YouTube Music поиск HTTP \(status)")
                return nil
            }
            return parseMusicSearch(root: root)
        } catch {
            print("YouTubeService: YouTube Music поиск ошибка: \(error.localizedDescription)")
            return nil
        }
    }

    /// Разбор ответа YouTube Music. Обходим дерево целиком: Google часто меняет вложенность,
    /// а сами элементы (`musicResponsiveListItemRenderer`) и токены продолжения стабильны.
    private func parseMusicSearch(root: [String: Any]) -> (tracks: [YouTubeTrack], nextToken: String?) {
        var items: [[String: Any]] = []
        var tokens: [String] = []
        for key in ["contents", "continuationContents", "onResponseReceivedCommands", "onResponseReceivedActions"] {
            if let node = root[key] {
                Self.collectMusicItems(node, items: &items, tokens: &tokens)
            }
        }

        var seen = Set<String>()
        var tracks: [YouTubeTrack] = []
        for item in items {
            guard let track = parseMusicItem(item), !seen.contains(track.id) else { continue }
            seen.insert(track.id)
            tracks.append(track)
        }
        rememberTracks(tracks)
        return (tracks, tokens.first)
    }

    private static func collectMusicItems(_ node: Any, items: inout [[String: Any]], tokens: inout [String]) {
        if let dict = node as? [String: Any] {
            if let item = dict["musicResponsiveListItemRenderer"] as? [String: Any] {
                items.append(item)
                return
            }
            if let next = dict["nextContinuationData"] as? [String: Any],
               let token = next["continuation"] as? String {
                tokens.append(token)
            }
            if let command = dict["continuationCommand"] as? [String: Any],
               let token = command["token"] as? String {
                tokens.append(token)
            }
            // Ключи сортируем, чтобы порядок обхода (и выдачи) не зависел от словаря
            for key in dict.keys.sorted() {
                if let value = dict[key], value is [String: Any] || value is [Any] {
                    collectMusicItems(value, items: &items, tokens: &tokens)
                }
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectMusicItems(value, items: &items, tokens: &tokens)
            }
        }
    }

    /// Одна строка выдачи: «Название» и «Исполнитель • Альбом • 3:45»
    private func parseMusicItem(_ item: [String: Any]) -> YouTubeTrack? {
        guard let videoId = Self.musicItemVideoId(item) else { return nil }

        let columns = item["flexColumns"] as? [[String: Any]] ?? []
        func columnText(_ index: Int) -> String {
            guard columns.indices.contains(index),
                  let column = columns[index]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                  let text = column["text"] as? [String: Any] else { return "" }
            if let runs = text["runs"] as? [[String: Any]] {
                return runs.compactMap { $0["text"] as? String }.joined()
            }
            return text["simpleText"] as? String ?? ""
        }

        let title = columnText(0).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        var parts = columnText(1)
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var duration = 0
        if let last = parts.last, last.contains(":") {
            duration = parseDurationString(last)
            if duration > 0 { parts.removeLast() }
        }
        if duration == 0, let fixed = (item["fixedColumns"] as? [[String: Any]])?.first,
           let renderer = fixed["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any],
           let text = renderer["text"] as? [String: Any] {
            let value = (text["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
                ?? (text["simpleText"] as? String ?? "")
            duration = parseDurationString(value)
        }
        // Без длительности это не песня (эфир, плейлист и т.п.)
        guard duration > 0 else { return nil }

        let typeLabels: Set<String> = ["песня", "song", "видео", "video", "клип", "эпизод", "episode"]
        if let first = parts.first, typeLabels.contains(first.lowercased()) {
            parts.removeFirst()
        }
        let artist = parts.first ?? "YouTube Music"

        return YouTubeTrack(
            id: videoId,
            title: title,
            uploader: artist,
            duration: duration,
            thumbnailUrl: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
        )
    }

    private static func musicItemVideoId(_ item: [String: Any]) -> String? {
        if let data = item["playlistItemData"] as? [String: Any],
           let id = data["videoId"] as? String, !id.isEmpty {
            return id
        }
        return findWatchVideoId(in: item)
    }

    private static func findWatchVideoId(in node: Any) -> String? {
        if let dict = node as? [String: Any] {
            if let watch = dict["watchEndpoint"] as? [String: Any],
               let id = watch["videoId"] as? String, !id.isEmpty {
                return id
            }
            for key in dict.keys.sorted() {
                if let value = dict[key], value is [String: Any] || value is [Any],
                   let id = findWatchVideoId(in: value) {
                    return id
                }
            }
        } else if let array = node as? [Any] {
            for value in array {
                if let id = findWatchVideoId(in: value) {
                    return id
                }
            }
        }
        return nil
    }

    private static func encodeQueryValue(_ value: String) -> String {
        // Токен уже может быть закодирован (%3D) — тогда не трогаем его
        if value.contains("%") { return value }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: - Метаданные и другая загрузка той же песни

    /// Запоминает название и длительность трека — пригодится, если сам ролик окажется недоступен
    func rememberTrack(_ track: YouTubeTrack) {
        rememberTracks([track])
    }

    private func rememberTracks(_ tracks: [YouTubeTrack]) {
        guard !tracks.isEmpty else { return }
        cacheLock.withLock {
            if knownTracks.count > 3000 {
                knownTracks.removeAll()
            }
            for track in tracks {
                // Не затираем полные данные пустыми (например, без длительности)
                if let existing = knownTracks[track.id], track.duration == 0, existing.duration > 0 {
                    continue
                }
                knownTracks[track.id] = track
            }
        }
    }

    /// Сначала YouTubeKit, затем прямой запрос плеера InnerTube.
    /// Порядок важен: ссылки YouTubeKit открываются в AVPlayer, а ссылки резервного клиента
    /// AVFoundation открыть не может (проверено смоук-тестом) — годятся в основном для скачивания.
    private func resolveStreamURL(for videoId: String) async -> URL? {
        if let url = await extractAudioURL(for: videoId, timeout: 20) {
            print("YouTubeService: ✅ Аудио URL через YouTubeKit: \(videoId)")
            return url
        }
        // Официальные клипы лейблов YouTubeKit часто не отдаёт (extractError)
        return await fetchAudioURLViaInnerTubePlayer(videoId: videoId)
    }

    /// Ищет ту же песню в каталоге YouTube Music (совпадение по длительности) и берёт её поток
    private func alternateUploadURL(for videoId: String) async -> URL? {
        guard let original = cacheLock.withLock({ knownTracks[videoId] }) else { return nil }

        let query = Self.songSearchQuery(title: original.title, artist: original.uploader)
        guard !query.isEmpty, let result = await searchMusicSongs(query: query) else { return nil }

        let tolerance = max(8, original.duration / 20)
        let candidates = result.tracks
            .filter { $0.id != videoId }
            .filter { original.duration <= 0 || abs($0.duration - original.duration) <= tolerance }
            .prefix(2)

        for candidate in candidates {
            if let url = await resolveStreamURL(for: candidate.id) {
                print("YouTubeService: ✅ Другая загрузка той же песни: \(candidate.id) вместо \(videoId)")
                return url
            }
        }
        print("YouTubeService: другая загрузка для \(videoId) не найдена (кандидатов: \(candidates.count))")
        return nil
    }

    /// «Rammstein - Sonne (Official Video)» + «Rammstein Official» → «Rammstein - Sonne»
    static func songSearchQuery(title: String, artist: String) -> String {
        var cleanTitle = title.replacingOccurrences(
            of: "\\s*[\\(\\[【][^\\)\\]】]*[\\)\\]】]",
            with: "",
            options: .regularExpression
        )
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanArtist = artist
        for suffix in [" - Topic", "VEVO", " Official", " official"] where cleanArtist.hasSuffix(suffix) {
            cleanArtist = String(cleanArtist.dropLast(suffix.count))
        }
        cleanArtist = cleanArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanArtist.isEmpty || cleanTitle.lowercased().contains(cleanArtist.lowercased()) {
            return cleanTitle
        }
        return "\(cleanArtist) \(cleanTitle)"
    }
}
