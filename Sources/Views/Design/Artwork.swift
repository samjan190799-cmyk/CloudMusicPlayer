import SwiftUI
import UIKit
import ImageIO
import Combine

// MARK: - Стабильный хеш (String.hashValue меняется между запусками)

enum StableHash {
    static func value(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for scalar in string.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return hash
    }
}

// MARK: - Сгенерированные обложки

/// Набор глубоких градиентов для треков без обложки.
/// Каждый трек получает свой цвет, стабильный между запусками.
enum GeneratedArtwork {
    private static let gradients: [(Color, Color)] = [
        (Color(red: 0.98, green: 0.42, blue: 0.33), Color(red: 0.45, green: 0.11, blue: 0.29)),
        (Color(red: 0.55, green: 0.47, blue: 1.00), Color(red: 0.15, green: 0.12, blue: 0.42)),
        (Color(red: 0.20, green: 0.82, blue: 0.62), Color(red: 0.04, green: 0.27, blue: 0.33)),
        (Color(red: 0.30, green: 0.63, blue: 1.00), Color(red: 0.08, green: 0.15, blue: 0.40)),
        (Color(red: 1.00, green: 0.71, blue: 0.25), Color(red: 0.52, green: 0.18, blue: 0.10)),
        (Color(red: 1.00, green: 0.33, blue: 0.56), Color(red: 0.30, green: 0.07, blue: 0.30)),
        (Color(red: 0.36, green: 0.86, blue: 0.95), Color(red: 0.12, green: 0.20, blue: 0.47)),
        (Color(red: 0.80, green: 0.55, blue: 0.98), Color(red: 0.32, green: 0.10, blue: 0.40))
    ]

    static func colors(for seed: String) -> (Color, Color) {
        gradients[Int(StableHash.value(seed) % UInt64(gradients.count))]
    }

    static func baseUIColor(for seed: String) -> UIColor {
        UIColor(colors(for: seed).0)
    }
}

struct GeneratedCover: View {
    let seed: String
    let title: String
    var symbol: String? = nil

    var body: some View {
        let pair = GeneratedArtwork.colors(for: seed)
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: side * 0.34, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                } else {
                    Text(initial)
                        .font(.system(size: side * 0.42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var initial: String {
        let letter = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .first(where: { $0.isLetter || $0.isNumber })
        return letter.map { String($0).uppercased() } ?? "♪"
    }
}

// MARK: - Кеш изображений

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: key as NSString, cost: Int(pixels * 4))
    }
}

// MARK: - Ключ обложки

/// Описывает, откуда брать обложку трека
struct ArtworkKey: Hashable {
    let id: String
    let title: String
    let localCoverURL: URL?
    let youTubeID: String?

    var cacheID: String {
        if let url = localCoverURL { return "file:" + url.path }
        if let ytID = youTubeID { return "yt:" + ytID }
        return "none:" + id
    }

    var hasRemoteOrLocalImage: Bool {
        localCoverURL != nil || youTubeID != nil
    }
}

private func isYouTubeSource(_ sourceName: String) -> Bool {
    sourceName.contains("YouTube") || sourceName == "Аудиокниги"
}

extension PlayerTrack {
    var artworkKey: ArtworkKey {
        ArtworkKey(
            id: id,
            title: title,
            localCoverURL: localCoverURL,
            youTubeID: localCoverURL == nil && isYouTubeSource(sourceName) ? id : nil
        )
    }
}

extension PlaylistTrack {
    var artworkKey: ArtworkKey {
        ArtworkKey(
            id: id,
            title: title,
            localCoverURL: localCoverURL,
            youTubeID: localCoverURL == nil && isYouTubeSource(sourceName) ? id : nil
        )
    }
}

extension LocalTrack {
    var artworkKey: ArtworkKey {
        ArtworkKey(
            id: id,
            title: title,
            localCoverURL: localCoverURL,
            youTubeID: localCoverURL == nil && source == .youtube ? id : nil
        )
    }
}

extension YouTubeTrack {
    var artworkKey: ArtworkKey {
        ArtworkKey(id: id, title: title, localCoverURL: nil, youTubeID: id)
    }
}

// MARK: - Загрузчик обложек

enum ArtworkLoader {
    private static let youTubeQualities = ["maxresdefault", "hqdefault", "mqdefault", "sddefault"]

    static func cacheKey(for key: ArtworkKey, maxPixel: CGFloat) -> String {
        key.cacheID + "@\(Int(maxPixel))"
    }

    /// Загружает изображение для ключа. `maxPixel` ограничивает размер локальных файлов.
    static func image(for key: ArtworkKey, maxPixel: CGFloat) async -> UIImage? {
        let storageKey = cacheKey(for: key, maxPixel: maxPixel)
        if let cached = ThumbnailCache.shared.get(storageKey) {
            return cached
        }

        var result: UIImage? = nil
        if let url = key.localCoverURL {
            result = downsampledImage(at: url, maxPixel: maxPixel)
        } else if let ytID = key.youTubeID {
            result = await youTubeImage(videoID: ytID)
        }

        if let image = result {
            ThumbnailCache.shared.set(storageKey, image: image)
        }
        return result
    }

    /// Быстрое уменьшение локальной картинки через ImageIO без декодирования полного размера
    static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 64)
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Обложка YouTube с цепочкой качеств maxres → hq → mq → sd
    static func youTubeImage(videoID: String) async -> UIImage? {
        if let cached = ThumbnailCache.shared.get(videoID) {
            return cached
        }
        for quality in youTubeQualities {
            if Task.isCancelled { return nil }
            guard let url = URL(string: "https://img.youtube.com/vi/\(videoID)/\(quality).jpg") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            guard let result = try? await URLSession.shared.data(for: request),
                  let http = result.1 as? HTTPURLResponse,
                  http.statusCode == 200,
                  let image = UIImage(data: result.0) else {
                continue
            }
            // YouTube отдаёт заглушку 120×90, если maxres нет
            if quality == "maxresdefault" && image.size.width <= 120 {
                continue
            }
            ThumbnailCache.shared.set(videoID, image: image)
            return image
        }
        return nil
    }
}

// MARK: - Обложка для Lock Screen (используется AudioPlayerManager)

enum RemoteCoverUtility {
    static func loadCover(for videoId: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = ThumbnailCache.shared.get(videoId) {
            completion(cached)
            return
        }
        Task.detached(priority: .utility) {
            let image = await ArtworkLoader.youTubeImage(videoID: videoId)
            completion(image)
        }
    }
}

// MARK: - Вью обложки

struct ArtworkView: View {
    let artwork: ArtworkKey
    var cornerRadius: CGFloat = Metrics.artworkRadius
    /// Сколько пикселей нужно загрузить (для списков достаточно ~200)
    var maxPixel: CGFloat = 220
    var symbol: String? = nil

    @State private var image: UIImage? = nil
    @State private var loadedID: String? = nil

    var body: some View {
        ZStack {
            if let image = image, loadedID == artwork.cacheID {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                GeneratedCover(seed: artwork.id, title: artwork.title, symbol: symbol)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .task(id: artwork.cacheID) {
            guard artwork.hasRemoteOrLocalImage else {
                image = nil
                loadedID = nil
                return
            }
            let loaded = await ArtworkLoader.image(for: artwork, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                image = loaded
                loadedID = artwork.cacheID
            }
        }
    }
}

// MARK: - Цвет из обложки

enum ArtworkColor {
    private static let cache = NSCache<NSString, UIColor>()

    /// Доминирующий «сочный» цвет изображения, подогнанный под тёмный фон
    static func dominant(from image: UIImage, cacheKey: String) -> UIColor {
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        let color = adjusted(rawDominant(from: image) ?? UIColor(white: 0.4, alpha: 1))
        cache.setObject(color, forKey: cacheKey as NSString)
        return color
    }

    /// Цвет для трека без обложки (из сгенерированного градиента)
    static func fallback(for seed: String) -> UIColor {
        adjusted(GeneratedArtwork.baseUIColor(for: seed))
    }

    private static func rawDominant(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        let side = 24
        let bytesPerRow = side * 4
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, weightSum: CGFloat = 0
        var plainRed: CGFloat = 0, plainGreen: CGFloat = 0, plainBlue: CGFloat = 0
        let count = side * side
        for index in 0..<count {
            let offset = index * 4
            let r = CGFloat(pixels[offset]) / 255
            let g = CGFloat(pixels[offset + 1]) / 255
            let b = CGFloat(pixels[offset + 2]) / 255
            plainRed += r
            plainGreen += g
            plainBlue += b

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
            // Предпочитаем насыщенные и не слишком тёмные пиксели
            let weight = saturation * saturation * maxC + 0.002
            red += r * weight
            green += g * weight
            blue += b * weight
            weightSum += weight
        }
        guard weightSum > 0 else { return nil }
        let vivid = UIColor(red: red / weightSum, green: green / weightSum, blue: blue / weightSum, alpha: 1)

        // Если картинка почти монохромная — берём средний цвет
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        vivid.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        if sat < 0.12 {
            let n = CGFloat(count)
            return UIColor(red: plainRed / n, green: plainGreen / n, blue: plainBlue / n, alpha: 1)
        }
        return vivid
    }

    /// Ограничивает яркость и насыщенность, чтобы цвет красиво лежал на тёмном фоне
    private static func adjusted(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let newSaturation = sat < 0.12 ? sat : min(max(sat, 0.38), 0.82)
        let newBrightness = min(max(bri, 0.42), 0.72)
        return UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: 1)
    }
}

// MARK: - Обложка и цвет текущего трека

/// Загружает обложку текущего трека в хорошем качестве и вычисляет его цвет.
/// Используется мини-плеером, полноэкранным плеером и главной.
final class NowPlayingArtwork: ObservableObject {
    static let shared = NowPlayingArtwork()

    @Published private(set) var image: UIImage? = nil
    @Published private(set) var color: Color = Color(white: 0.35)
    @Published private(set) var trackID: String? = nil

    /// Размер обложки для плеера в пикселях
    private static let playerPixels: CGFloat = 1000

    private var cancellable: AnyCancellable?
    private var loadTask: Task<Void, Never>?

    private init() {
        cancellable = AudioPlayerManager.shared.$currentTrack
            .removeDuplicates { $0?.id == $1?.id }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.load(track)
            }
    }

    private func load(_ track: PlayerTrack?) {
        loadTask?.cancel()
        guard let track = track else {
            image = nil
            trackID = nil
            return
        }

        let key = track.artworkKey
        trackID = track.id

        // Обложка уже в кеше — показываем сразу, без мигания заглушки
        if let cached = ThumbnailCache.shared.get(ArtworkLoader.cacheKey(for: key, maxPixel: Self.playerPixels)) {
            image = cached
            let uiColor = ArtworkColor.dominant(from: cached, cacheKey: key.cacheID)
            withAnimation(.easeInOut(duration: 0.5)) {
                color = Color(uiColor)
            }
            return
        }

        let fallbackColor = Color(ArtworkColor.fallback(for: key.id))
        image = nil
        withAnimation(.easeInOut(duration: 0.5)) {
            color = fallbackColor
        }

        guard key.hasRemoteOrLocalImage else { return }

        loadTask = Task { [weak self] in
            let loaded = await ArtworkLoader.image(for: key, maxPixel: Self.playerPixels)
            guard !Task.isCancelled, let loaded = loaded else { return }
            let uiColor = ArtworkColor.dominant(from: loaded, cacheKey: key.cacheID)
            await MainActor.run {
                guard let self = self, self.trackID == track.id else { return }
                self.image = loaded
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.color = Color(uiColor)
                }
            }
        }
    }
}

/// Обложка текущего трека (с уже загруженным изображением из NowPlayingArtwork)
struct NowPlayingArtworkView: View {
    let track: PlayerTrack
    var cornerRadius: CGFloat
    @ObservedObject private var artwork = NowPlayingArtwork.shared

    var body: some View {
        ZStack {
            if let image = artwork.image, artwork.trackID == track.id {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                GeneratedCover(seed: track.artworkKey.id, title: track.title)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
