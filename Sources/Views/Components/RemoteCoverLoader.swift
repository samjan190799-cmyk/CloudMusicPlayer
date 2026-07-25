import SwiftUI

// MARK: - Универсальный загрузчик обложек для онлайн-треков

/// Загружает и кеширует обложки YouTube-треков с fallback-цепочкой разрешений.
/// Использует `ThumbnailCache` (NSCache) из YouTubeView для единого кеша.
struct RemoteCoverLoader: View {
    let trackId: String
    let sourceName: String
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 12
    var isCircle: Bool = false
    /// Показывать ли начальную букву трека в качестве плейсхолдера
    var placeholderLetter: String? = nil
    
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    
    /// Цепочка URL для fallback (от высокого к низкому разрешению)
    private var urlChain: [String] {
        if sourceName.contains("YouTube") || sourceName == "Аудиокниги" {
            return [
                "https://img.youtube.com/vi/\(trackId)/maxresdefault.jpg",
                "https://img.youtube.com/vi/\(trackId)/hqdefault.jpg",
                "https://img.youtube.com/vi/\(trackId)/mqdefault.jpg",
                "https://img.youtube.com/vi/\(trackId)/sddefault.jpg"
            ]
        }
        return []
    }
    
    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.25)))
            } else if isLoading {
                // Пульсирующий плейсхолдер во время загрузки
                ZStack {
                    if isCircle {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .cyan.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .cyan.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                        .scaleEffect(min(width, height) > 100 ? 1.0 : 0.7)
                }
                .frame(width: width, height: height)
            } else {
                // Финальный плейсхолдер, если ничего не загрузилось
                ZStack {
                    if isCircle {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.08, blue: 0.35), Color(red: 0.05, green: 0.08, blue: 0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    if let letter = placeholderLetter {
                        Text(letter.uppercased())
                            .font(.system(size: min(width, height) * 0.35, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: min(width, height) * 0.3, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipShape(
            isCircle
                ? AnyShape(Circle())
                : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
        .task(id: trackId) {
            await loadCover()
        }
    }
    
    private func loadCover() async {
        // 1. Проверяем кеш (общий с YouTubeView)
        if let cached = ThumbnailCache.shared.get(trackId) {
            image = cached
            isLoading = false
            return
        }
        
        guard !urlChain.isEmpty else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        // 2. Пробуем загрузить с fallback-цепочкой
        for urlStr in urlChain {
            guard !Task.isCancelled else { return }
            guard let url = URL(string: urlStr) else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let img = UIImage(data: data),
                      img.size.width > 120 else {
                    continue
                }
                
                // Сохраняем в общий кеш
                ThumbnailCache.shared.set(trackId, image: img)
                image = img
                isLoading = false
                return
            } catch {
                continue
            }
        }
        
        isLoading = false
    }
}

// MARK: - Вспомогательная обёртка для type-erasure Shape

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Утилита загрузки обложки для Lock Screen и Widget

/// Загружает UIImage обложки YouTube-трека для использования в MPNowPlayingInfoCenter и Widget.
/// Возвращает результат через completion-handler (не SwiftUI).
enum RemoteCoverUtility {
    
    private static let urlChain: [String] = ["maxresdefault", "hqdefault", "mqdefault"]
    
    /// Асинхронно загружает обложку YouTube-трека. Кеширует через `ThumbnailCache`.
    static func loadCover(for videoId: String, completion: @escaping (UIImage?) -> Void) {
        // 1. Кеш
        if let cached = ThumbnailCache.shared.get(videoId) {
            completion(cached)
            return
        }
        
        Task.detached(priority: .utility) {
            for quality in urlChain {
                let urlStr = "https://img.youtube.com/vi/\(videoId)/\(quality).jpg"
                guard let url = URL(string: urlStr) else { continue }
                
                do {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 8
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let http = response as? HTTPURLResponse,
                          http.statusCode == 200,
                          let img = UIImage(data: data),
                          img.size.width > 120 else {
                        continue
                    }
                    
                    ThumbnailCache.shared.set(videoId, image: img)
                    completion(img)
                    return
                } catch {
                    continue
                }
            }
            
            completion(nil)
        }
    }
}
