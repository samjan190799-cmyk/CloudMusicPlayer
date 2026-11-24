import Foundation
import AVFoundation

// Смоук-тест YouTube-части CloudMusicPlayer на реальной сети.
// Прогоняет НАСТОЯЩИЙ YouTubeService приложения: поиск, пагинацию, чарты, извлечение аудиопотока
// через YouTubeKit, скачивание фрагмента без подмены заголовков и открытие потока в AVFoundation.
//
// Использование: ./run.sh [videoId ...]   — дополнительные видео для проверки потока

// MARK: - Мини-фреймворк отчёта

var failures: [String] = []
var warnings: [String] = []
var reportLines: [String] = []

@MainActor
func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    let line = condition ? "✅ \(name)" : "❌ \(name)\(detail.isEmpty ? "" : " — \(detail)")"
    print(line)
    reportLines.append(line)
    if !condition { failures.append(name) }
}

@MainActor
func warn(_ message: String) {
    let line = "⚠️ \(message)"
    print(line)
    reportLines.append(line)
    warnings.append(message)
}

@MainActor
func section(_ title: String) {
    print("\n=== \(title) ===")
    reportLines.append("\n**\(title)**\n")
}

@MainActor
func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    return condition()
}

func audioURL(for videoId: String) async -> URL? {
    await withCheckedContinuation { continuation in
        YouTubeService.shared.getAudioURL(for: videoId) { continuation.resume(returning: $0) }
    }
}

let service = YouTubeService.shared

/// Как приложение поступает со ссылками резервного клиента: скачивает файл кусками (Range)
/// и открывает локально — целиком googlevideo такие ссылки не отдаёт (403)
func downloadAndOpenLocally(_ url: URL, name: String) async -> (ok: Bool, detail: String) {
    let partial = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).part")
    let started = Date()
    guard await RangedDownloader.download(from: url, to: partial) else {
        return (false, "загрузка кусками не удалась")
    }
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(started))
    do {
        let ext = AudioFileSniffer.fileExtension(for: partial, fallback: "m4a")
        let local = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).\(ext)")
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: partial, to: local)
        defer { try? FileManager.default.removeItem(at: local) }
        let size = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? Int) ?? 0
        let asset = AVURLAsset(url: local)
        let (isPlayable, duration) = try await asset.load(.isPlayable, .duration)
        let seconds = CMTimeGetSeconds(duration)
        return (isPlayable && seconds > 0, ".\(ext), \(size / 1024) КБ за \(elapsed) с, длительность \(Int(seconds)) с, playable=\(isPlayable)")
    } catch {
        return (false, error.localizedDescription)
    }
}

// MARK: - 1. Определение формата файла (AudioFileSniffer)

section("AudioFileSniffer")
do {
    let tmp = FileManager.default.temporaryDirectory
    let samples: [(String, [UInt8], String)] = [
        ("M4A (ftyp)", [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20], "m4a"),
        ("MP3 (ID3)", [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], "mp3"),
        ("MP3 (sync)", [0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], "mp3"),
        ("AAC (ADTS)", [0xFF, 0xF1, 0x50, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], "aac"),
        ("FLAC", [0x66, 0x4C, 0x61, 0x43, 0x00, 0x00, 0x00, 0x22, 0x00, 0x00, 0x00, 0x00], "flac"),
        ("WAV", [0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45], "wav"),
        ("HTML-ошибка", Array("<html><body>".utf8), "mp3")
    ]
    for (name, bytes, expected) in samples {
        let url = tmp.appendingPathComponent(UUID().uuidString)
        try Data(bytes).write(to: url)
        let detected = AudioFileSniffer.fileExtension(for: url)
        check(detected == expected, "Сигнатура \(name) → .\(expected)", "получено .\(detected)")
        try? FileManager.default.removeItem(at: url)
    }
} catch {
    check(false, "Запись временных файлов", error.localizedDescription)
}

// MARK: - 2. Поиск InnerTube

section("Поиск")
let query = "Rammstein Sonne"
service.search(query: query)
let searchDone = await waitUntil(timeout: 25) { !service.tracks.isEmpty || service.errorMessage != nil }
check(searchDone && !service.tracks.isEmpty, "Поиск «\(query)» вернул результаты",
      service.errorMessage ?? (searchDone ? "пусто" : "таймаут"))
check(service.tracks.allSatisfy { $0.duration > 0 }, "В выдаче нет прямых эфиров (у всех есть длительность)")
if let first = service.tracks.first {
    print("   первый результат: \(first.title) — \(first.uploader) [\(first.id), \(first.duration)с]")
}
let firstPageCount = service.tracks.count
print("   результатов на первой странице: \(firstPageCount)")

// MARK: - 3. Пагинация

section("Пагинация")
if service.canLoadMore {
    // search() завершается асинхронно — ждём, пока снимется флаг загрузки
    _ = await waitUntil(timeout: 5) { !service.isLoading }
    service.loadMore()
    let grew = await waitUntil(timeout: 25) { service.tracks.count > firstPageCount }
    check(grew, "Подгрузка следующей страницы", "было \(firstPageCount), стало \(service.tracks.count)")
    check(Set(service.tracks.map(\.id)).count == service.tracks.count, "Без дубликатов между страницами")
} else {
    warn("YouTube не вернул токен продолжения — пагинация не проверена")
}

// MARK: - 3a. Поиск песен YouTube Music

section("Поиск песен YouTube Music")
var musicSongIds: [String] = []
if let songsPage = await service.searchMusicSongs(query: query) {
    check(!songsPage.tracks.isEmpty, "Каталог песен вернул результаты", "пусто — возможно, изменилась разметка ответа")
    check(songsPage.tracks.allSatisfy { $0.duration > 0 }, "У всех песен есть длительность")
    check(songsPage.tracks.allSatisfy { !$0.uploader.isEmpty && $0.uploader != "YouTube Music" },
          "У песен распознан исполнитель")
    for song in songsPage.tracks.prefix(3) {
        print("   \(song.title) — \(song.uploader) [\(song.id), \(song.duration)с]")
    }
    if let first = songsPage.tracks.first, !first.title.localizedCaseInsensitiveContains("sonne") {
        warn("Первая песня не «Sonne»: \(first.title)")
    }
    musicSongIds = songsPage.tracks.prefix(1).map(\.id)

    if let token = songsPage.nextToken {
        if let nextPage = await service.searchMusicSongs(query: query, continuation: token) {
            check(!nextPage.tracks.isEmpty, "Следующая страница песен", "пусто")
            let firstIds = Set(songsPage.tracks.map(\.id))
            let repeated = nextPage.tracks.filter { firstIds.contains($0.id) }.count
            check(repeated < nextPage.tracks.count || nextPage.tracks.isEmpty, "Следующая страница песен не повторяет первую",
                  "повторов: \(repeated)")
        } else {
            check(false, "Следующая страница песен", "сетевая ошибка")
        }
    } else {
        warn("YouTube Music не вернул токен продолжения — догрузка песен не проверена")
    }
} else {
    check(false, "Каталог песен YouTube Music отвечает", "сетевая ошибка или HTTP ≠ 200")
}

// search() параллельно наполняет и список песен для экрана поиска
let songsPublished = await waitUntil(timeout: 20) { !service.songs.isEmpty || !service.isSongsLoading }
check(songsPublished && !service.songs.isEmpty, "search() показывает песни на экране поиска", "songs пуст")

check(YouTubeService.songSearchQuery(title: "Rammstein - Sonne (Official Video)", artist: "Rammstein Official") == "Rammstein - Sonne",
      "Запрос для поиска другой загрузки очищается от «(Official Video)»",
      YouTubeService.songSearchQuery(title: "Rammstein - Sonne (Official Video)", artist: "Rammstein Official"))
check(YouTubeService.songSearchQuery(title: "Du hast", artist: "Rammstein - Topic") == "Rammstein Du hast",
      "Запрос добавляет исполнителя без « - Topic»",
      YouTubeService.songSearchQuery(title: "Du hast", artist: "Rammstein - Topic"))

// MARK: - 4. Чарты (грузятся при создании сервиса)

section("Чарты")
let chartsLoaded = await waitUntil(timeout: 30) { !service.trendingTracks.isEmpty }
check(chartsLoaded, "Чарты «\(service.selectedRegion.title)» загружены", "пусто")
print("   треков в чарте: \(service.trendingTracks.count)")

// MARK: - 5. Аудиопотоки: YouTubeKit → HTTP → формат → AVFoundation

section("Аудиопотоки")
var videoIds = ["dQw4w9WgXcQ"] + Array(CommandLine.arguments.dropFirst())
videoIds += service.tracks.prefix(3).map(\.id)
videoIds += musicSongIds // официальная аудиодорожка из каталога YouTube Music
videoIds = videoIds.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

var extractedCount = 0
var botBlockedCount = 0
for videoId in videoIds {
    let started = Date()
    guard let streamURL = await audioURL(for: videoId) else {
        let reason = service.lastExtractionFailureReason(for: videoId) ?? "YouTubeKit не вернул ссылку"
        if reason.localizedCaseInsensitiveContains("not a bot") {
            // Антибот-проверка YouTube для IP дата-центров GitHub: код отработал верно, на телефоне её обычно нет
            botBlockedCount += 1
            warn("[\(videoId)] YouTube требует подтверждения «не бот» для IP раннера — пропущено (\(reason))")
        } else {
            check(false, "[\(videoId)] Извлечение аудиопотока", reason)
        }
        continue
    }
    extractedCount += 1
    let elapsed = String(format: "%.1f", Date().timeIntervalSince(started))
    check(true, "[\(videoId)] Ссылка получена за \(elapsed) с")

    // Скачиваем первые 256 КБ без каких-либо своих заголовков — как это делают AVPlayer и DownloadManager
    var request = URLRequest(url: streamURL)
    request.setValue("bytes=0-262143", forHTTPHeaderField: "Range")
    request.timeoutInterval = 20
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        check([200, 206].contains(status), "[\(videoId)] googlevideo отдаёт данные", "HTTP \(status)")

        let chunkURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(videoId).chunk")
        try data.write(to: chunkURL)
        let ext = AudioFileSniffer.fileExtension(for: chunkURL, fallback: "unknown")
        if ext == "m4a" {
            check(true, "[\(videoId)] Контейнер M4A (AAC), \(data.count / 1024) КБ")
        } else {
            warn("[\(videoId)] Неожиданный контейнер: .\(ext)")
        }
        try? FileManager.default.removeItem(at: chunkURL)
    } catch {
        check(false, "[\(videoId)] Скачивание фрагмента", error.localizedDescription)
    }

    // Открываем так же, как плеер приложения: ссылки резервного клиента он сначала скачивает
    if service.requiresDownloadBeforePlayback(streamURL) {
        let result = await downloadAndOpenLocally(streamURL, name: videoId)
        check(result.ok, "[\(videoId)] Ссылка резервного клиента: скачанный файл играет в AVFoundation", result.detail)
    } else {
        let asset = AVURLAsset(url: streamURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        do {
            let (isPlayable, duration) = try await asset.load(.isPlayable, .duration)
            let seconds = CMTimeGetSeconds(duration)
            check(isPlayable && seconds > 0, "[\(videoId)] AVFoundation открывает поток",
                  "playable=\(isPlayable), duration=\(seconds)")
        } catch {
            check(false, "[\(videoId)] AVFoundation открывает поток", error.localizedDescription)
        }
    }
}

// Хотя бы одно видео должно извлекаться, иначе проверка потоков ничего не доказывает
check(extractedCount > 0, "Хотя бы один поток извлечён и проверен", "YouTube заблокировал все запросы с раннера")

if extractedCount == 0 && !service.tracks.isEmpty && botBlockedCount == 0 {
    warn("Поиск работает, но ни один поток не извлечён. На серверах GitHub YouTube часто требует " +
         "«подтвердите, что вы не бот» для IP дата-центров — на телефоне результат может отличаться. " +
         "Смотрите сообщения YouTubeKit выше.")
}

// MARK: - 5a. Резервный клиент: скачать целиком и играть файл

section("Резервный клиент")
if let fallbackURL = await service.fallbackAudioURL(for: "dQw4w9WgXcQ") {
    check(service.requiresDownloadBeforePlayback(fallbackURL), "Ссылка резервного клиента помечена «сначала скачать»")
    let result = await downloadAndOpenLocally(fallbackURL, name: "fallback-dQw4w9WgXcQ")
    check(result.ok, "Ссылка резервного клиента скачивается кусками и играет в AVFoundation", result.detail)
    print("   \(result.detail)")
} else {
    let reason = service.lastExtractionFailureReason(for: "dQw4w9WgXcQ") ?? "нет ссылки"
    warn("Резервный клиент не вернул ссылку (\(reason)) — проверка скачивания пропущена")
}

// MARK: - 6. Объединение одновременных запросов

section("Параллельные запросы")
if let dedupeId = videoIds.first {
    service.invalidateStreamCache(for: dedupeId)
    async let a = audioURL(for: dedupeId)
    async let b = audioURL(for: dedupeId)
    async let c = audioURL(for: dedupeId)
    let results = await [a, b, c]
    check(results.allSatisfy { $0 != nil } && Set(results.compactMap { $0 }).count == 1,
          "3 одновременных запроса получают одну и ту же ссылку")
}

// MARK: - Итог

let summary = failures.isEmpty
    ? "✅ Все проверки пройдены (предупреждений: \(warnings.count))"
    : "❌ Провалено проверок: \(failures.count) из \(reportLines.filter { $0.hasPrefix("✅") || $0.hasPrefix("❌") }.count)"
print("\n\(summary)")

if let summaryPath = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] {
    let markdown = "## YouTube smoke test\n\n\(summary)\n" + reportLines.joined(separator: "\n") + "\n"
    if let handle = FileHandle(forWritingAtPath: summaryPath) {
        handle.seekToEndOfFile()
        handle.write(Data(markdown.utf8))
        try? handle.close()
    }
}

exit(failures.isEmpty ? 0 : 1)
