import SwiftUI
import UIKit
import CoreImage

// MARK: - Обложка текущего трека + адаптивный цвет

/// Загружает обложку текущего трека (локальную или YouTube) и вычисляет её доминирующий цвет,
/// чтобы фон и свечение плеера подстраивались под артворк (как в Apple Music / Spotify).
final class NowPlayingArtworkLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var tint: Color = Color(white: 0.55)

    private var loadedTrackId: String?

    func load(for track: PlayerTrack?) {
        guard let track = track else {
            loadedTrackId = nil
            image = nil
            tint = Color(white: 0.55)
            return
        }
        guard track.id != loadedTrackId else { return }
        loadedTrackId = track.id

        let trackId = track.id
        if let coverURL = track.localCoverURL {
            Task.detached(priority: .userInitiated) {
                let img = UIImage(contentsOfFile: coverURL.path)
                let color = img?.dominantColor()
                DispatchQueue.main.async {
                    self.apply(img, color: color, for: trackId)
                }
            }
        } else if track.sourceName.contains("YouTube") || track.sourceName == "Аудиокниги" {
            if let cached = ThumbnailCache.shared.get(trackId) {
                image = cached
                Task.detached(priority: .userInitiated) {
                    let color = cached.dominantColor()
                    DispatchQueue.main.async {
                        self.apply(cached, color: color, for: trackId)
                    }
                }
            } else {
                image = nil
                RemoteCoverUtility.loadCover(for: trackId) { img in
                    let color = img?.dominantColor()
                    DispatchQueue.main.async {
                        self.apply(img, color: color, for: trackId)
                    }
                }
            }
        } else {
            image = nil
            tint = Color(white: 0.55)
        }
    }

    private func apply(_ img: UIImage?, color: UIColor?, for trackId: String) {
        guard trackId == loadedTrackId else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            image = img
            tint = color.map { Color(uiColor: $0) } ?? Color(white: 0.55)
        }
    }
}

extension UIImage {
    /// Средний цвет изображения, нормализованный по яркости, чтобы подходить для свечения на тёмном фоне
    func dominantColor() -> UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]), let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let base = UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard base.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return base }
        return UIColor(
            hue: h,
            saturation: min(s * 1.25, 0.85),
            brightness: min(max(b, 0.45), 0.8),
            alpha: 1
        )
    }
}

// MARK: - Представление обложки

/// Обложка трека: загруженный артворк или аккуратный монохромный плейсхолдер
struct ArtworkImageView: View {
    let image: UIImage?
    let title: String
    var cornerRadius: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    LinearGradient(
                        colors: [Color(white: 0.16), Color(white: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: geo.size.width * 0.28, weight: .light))
                        .foregroundColor(.white.opacity(0.22))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .accessibilityLabel(Text("Обложка: \(title)"))
    }
}

// MARK: - Адаптивный фон плеера

/// Размытая обложка + цветовое свечение + затемняющий градиент
struct AdaptiveArtworkBackground: View {
    let image: UIImage?
    let tint: Color
    var intensity: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.6)
                        .blur(radius: 70)
                        .opacity(0.55)
                        .clipped()
                }

                RadialGradient(
                    colors: [tint.opacity(0.55 * intensity), .clear],
                    center: .init(x: 0.5, y: 0.28),
                    startRadius: 10,
                    endRadius: geo.size.height * 0.6
                )
                .blendMode(.plusLighter)
                .opacity(0.6)

                LinearGradient(
                    colors: [Color.black.opacity(0.15), Color.black.opacity(0.55), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
