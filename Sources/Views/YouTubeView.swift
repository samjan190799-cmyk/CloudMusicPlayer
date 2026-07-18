import SwiftUI

// MARK: - Кастомный загрузчик обложек YouTube с fallback-цепочкой и кешем

/// Загружает обложку YouTube с fallback:
/// maxresdefault.jpg → hqdefault.jpg → mqdefault.jpg → sddefault.jpg → placeholder
struct YouTubeThumbnail: View {
    let videoId: String
    let width: CGFloat
    let height: CGFloat

    @State private var image: UIImage? = nil
    @State private var isLoading = true

    // Приоритетная цепочка качества обложек YouTube
    private var urlChain: [String] {
        [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/sddefault.jpg"
        ]
    }

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if isLoading {
                // Шиммер-плейсхолдер
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: width, height: height)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(20))
                    )
            } else {
                // Заглушка при ошибке загрузки
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: min(width, height) * 0.35))
                    )
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(6)
        .task(id: videoId) {
            await loadWithFallback(urlChain: urlChain)
        }
    }

    private func loadWithFallback(urlChain: [String]) async {
        // Проверка памяти кеша
        if let cached = ThumbnailCache.shared.get(videoId) {
            image = cached
            isLoading = false
            return
        }

        isLoading = true

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
                      // maxresdefault бывает пустым (серым 120x90) — проверяем реальный размер
                      img.size.width > 120 else {
                    continue
                }

                ThumbnailCache.shared.set(videoId, image: img)
                image = img
                isLoading = false
                return
            } catch {
                continue
            }
        }

        isLoading = false // Все попытки провалились — показываем заглушку
    }
}

// MARK: - Простой кеш обложек (NSCache — автоматически чистится при нехватке памяти)

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200      // Максимум 200 обложек в памяти
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        let bytes = image.jpegData(compressionQuality: 0.5)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: bytes)
    }
}

// MARK: - Основной экран YouTube

struct YouTubeView: View {
    @ObservedObject var service = YouTubeService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared

    @State private var searchQuery = ""
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil

    var body: some View {
        NavigationView {
            ZStack {
                // Фон
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.10, green: 0.03, blue: 0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Поисковая строка
                    searchBar

                    if service.isLoading && service.tracks.isEmpty {
                        loadingView
                    } else if let error = service.errorMessage, service.tracks.isEmpty {
                        errorView(message: error)
                    } else if service.tracks.isEmpty {
                        emptyStateView
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("YouTube Музыка")
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Поисковая строка

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.red)

            TextField("Исполнитель, трек, альбом...", text: $searchQuery)
                .foregroundColor(.white)
                .submitLabel(.search)
                .onSubmit { performSearch() }

            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    service.tracks = []
                    service.errorMessage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: searchQuery.isEmpty)
    }

    // MARK: - Состояния UI

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                .scaleEffect(1.4)
            Text("Поиск в YouTube...")
                .foregroundColor(.gray)
                .font(.system(size: 15))
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 52))
                .foregroundColor(.red.opacity(0.8))
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Повторить") { performSearch() }
                .foregroundColor(.red)
                .fontWeight(.bold)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12))
                .cornerRadius(10)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 68))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("Поиск музыки по всему миру")
                .font(.title3).fontWeight(.bold)
                .foregroundColor(.white)
            Text("Введите название трека, исполнителя или альбома.\nПоиск идёт параллельно по 9 серверам — результат мгновенно.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            // Подсказка про API ключи
            VStack(alignment: .leading, spacing: 8) {
                Label("Зачем нужны API ключи?", systemImage: "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text("API ключи (Gemini/GPT/Claude) нужны ТОЛЬКО для умной очистки названий треков через ИИ. Например: «Drake - God's Plan (Official Video) [4K] lyrics» → «God's Plan · Drake». Без ключа поиск и воспроизведение работают полностью.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.orange.opacity(0.07))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Список результатов

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(service.tracks) { track in
                    trackRow(track: track)
                }

                if service.canLoadMore {
                    loadMoreButton
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var loadMoreButton: some View {
        Button(action: { service.loadMore() }) {
            HStack(spacing: 10) {
                if service.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .red))
                } else {
                    Image(systemName: "chevron.down.circle")
                        .foregroundColor(.red)
                    Text("Загрузить ещё")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Ряд трека

    private func trackRow(track: YouTubeTrack) -> some View {
        let downloadStatus = downloadManager.getDownloadStatus(for: track.id)
        let isPlaying = playerManager.currentTrack?.id == track.id

        return HStack(spacing: 12) {
            // Кнопка воспроизведения с обложкой
            Button(action: { playOnlineTrack(track) }) {
                HStack(spacing: 12) {
                    ZStack {
                        YouTubeThumbnail(videoId: track.id, width: 64, height: 46)

                        // Оверлей при воспроизведении
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 64, height: 46)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 16))
                                .shadow(color: .black, radius: 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isPlaying ? .cyan : .white)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(track.uploader)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)

                            if track.duration > 0 {
                                Text("·")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 11))
                                Text(formatDuration(track.duration))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 4)

            // Контекстное меню
            Menu {
                Button(action: {
                    let pt = track.toPlaylistTrack()
                    playlistManager.toggleFavorite(track: pt)
                }) {
                    Label(
                        playlistManager.isTrackFavorite(trackId: track.id) ? "Убрать из избранного" : "Добавить в избранное",
                        systemImage: playlistManager.isTrackFavorite(trackId: track.id) ? "heart.slash.fill" : "heart.fill"
                    )
                }
                Button(action: { selectedTrackForPlaylist = track.toPlaylistTrack() }) {
                    Label("Добавить в плейлист", systemImage: "music.note.list")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }

            // Индикатор/кнопка скачивания
            downloadButton(for: track, status: downloadStatus)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isPlaying ? Color.cyan.opacity(0.07) : Color.white.opacity(0.03))
        .cornerRadius(12)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func downloadButton(for track: YouTubeTrack, status: DownloadStatus) -> some View {
        switch status {
        case .notDownloaded:
            Button(action: { downloadManager.downloadYouTubeTrack(track) }) {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.purple)
                    .font(.system(size: 16))
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 30, height: 30)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.cyan, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Button(action: { downloadManager.cancelDownload(trackId: track.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.cyan)
                .font(.system(size: 20))
                .padding(6)
        case .failed:
            Button(action: { downloadManager.downloadYouTubeTrack(track) }) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
    }

    // MARK: - Helpers

    private func performSearch() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        service.search(query: q)
    }

    private func playOnlineTrack(_ track: YouTubeTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        let playerTrack = PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.uploader,
            sourceName: "YouTube (Онлайн)",
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: nil,
            duration: Double(track.duration)
        )
        let queue = service.tracks.map { item in
            PlayerTrack(
                id: item.id,
                title: item.title,
                artist: item.uploader,
                sourceName: "YouTube (Онлайн)",
                localURL: nil,
                remoteURL: nil,
                googleFileId: nil,
                localCoverURL: nil,
                duration: Double(item.duration)
            )
        }
        playerManager.play(track: playerTrack, in: queue)
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Конвертация YouTubeTrack → PlaylistTrack

extension YouTubeTrack {
    func toPlaylistTrack() -> PlaylistTrack {
        PlaylistTrack(
            id: id,
            title: title,
            artist: uploader,
            sourceName: "YouTube",
            localRelativePath: nil,
            remoteURLString: nil,
            googleFileId: nil,
            duration: Double(duration)
        )
    }
}
