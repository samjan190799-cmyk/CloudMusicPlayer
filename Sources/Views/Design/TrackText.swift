import Foundation

/// Приводит «грязные» названия файлов и видео к виду «Название — Исполнитель».
/// Данные треков не меняются — только то, что видит пользователь.
enum TrackText {
    struct Display: Equatable {
        let title: String
        let artist: String
    }

    /// Имена-заглушки, которые сервисы подставляют вместо исполнителя
    private static let placeholderArtists: Set<String> = [
        "", "google drive", "яндекс диск", "устройство / файлы", "файлы ios", "импорт",
        "telegram", "telegram audio", "youtube", "youtube music", "медиатека", "загрузки",
        "скачанный файл", "неизвестный исполнитель", "apple music"
    ]

    private static let separators = [" — ", " – ", " - ", " -- "]

    /// Мусор в скобках: (Official Video), [Lyrics], (Премьера клипа, 2024) и т.п.
    private static let noiseRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "\\s*[\\(\\[【][^\\)\\]】]*(official|video|audio|lyric|visuali[sz]er|клип|премьера|видео|текст|hd|4k|mv|m/v|hq)[^\\)\\]】]*[\\)\\]】]",
        options: [.caseInsensitive]
    )

    private static var cache: [String: Display] = [:]

    static let unknownArtist = "Неизвестный исполнитель"

    static func display(title: String, artist: String?) -> Display {
        let cacheKey = title + "\u{1}" + (artist ?? "")
        if let cached = cache[cacheKey] {
            return cached
        }
        let result = compute(title: title, artist: artist)
        if cache.count > 3000 {
            cache.removeAll()
        }
        cache[cacheKey] = result
        return result
    }

    private static func compute(title rawTitle: String, artist rawArtist: String?) -> Display {
        var title = stripExtension(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        var artist = cleanArtist(rawArtist ?? "")
        let artistIsPlaceholder = placeholderArtists.contains(artist.lowercased())

        // «Исполнитель - Название»
        for separator in separators {
            guard let range = title.range(of: separator) else { continue }
            let left = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !left.isEmpty, !right.isEmpty else { continue }

            let leftLower = left.lowercased()
            let artistLower = artist.lowercased()
            let leftMatchesArtist = !artistLower.isEmpty &&
                (leftLower.contains(artistLower) || artistLower.contains(leftLower))

            if artistIsPlaceholder || leftMatchesArtist {
                artist = left
                title = right
            }
            break
        }

        title = stripNoise(title)
        if title.isEmpty {
            title = stripExtension(rawTitle)
        }
        if placeholderArtists.contains(artist.lowercased()) {
            artist = rawArtist.flatMap { $0.isEmpty ? nil : $0 } ?? unknownArtist
        }
        return Display(title: title, artist: artist)
    }

    private static func stripExtension(_ value: String) -> String {
        let extensions = [".mp3", ".m4a", ".flac", ".wav", ".aac", ".ogg", ".opus", ".wma", ".mp4", ".webm"]
        let lower = value.lowercased()
        for ext in extensions where lower.hasSuffix(ext) {
            return String(value.dropLast(ext.count))
        }
        return value
    }

    private static func cleanArtist(_ value: String) -> String {
        var artist = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if artist.hasSuffix(" - Topic") {
            artist = String(artist.dropLast(" - Topic".count))
        }
        if artist.hasSuffix("VEVO") && artist.count > 4 {
            artist = String(artist.dropLast(4))
        }
        return artist.trimmingCharacters(in: .whitespaces)
    }

    private static func stripNoise(_ value: String) -> String {
        guard let regex = noiseRegex else { return value }
        let range = NSRange(value.startIndex..., in: value)
        let cleaned = regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "")
        return cleaned
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Удобные обёртки

extension PlayerTrack {
    var display: TrackText.Display { TrackText.display(title: title, artist: artist) }
}

extension PlaylistTrack {
    var display: TrackText.Display { TrackText.display(title: title, artist: artist) }
}

extension LocalTrack {
    var display: TrackText.Display { TrackText.display(title: title, artist: artist) }
}

extension YouTubeTrack {
    var display: TrackText.Display { TrackText.display(title: title, artist: uploader) }
}
