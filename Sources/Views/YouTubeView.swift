import SwiftUI

// MARK: - Кастомный загрузчик обложек YouTube с fallback-цепочкой и кешем

struct YouTubeThumbnail: View {
    let videoId: String
    let width: CGFloat
    let height: CGFloat

    @State private var image: UIImage? = nil
    @State private var isLoading = true

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.accentGradient)
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                            .font(.system(size: min(width, height) * 0.35, weight: .bold))
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: videoId) {
            await loadWithFallback(urlChain: urlChain)
        }
    }

    private func loadWithFallback(urlChain: [String]) async {
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
                request.timeoutInterval = 6
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let img = UIImage(data: data),
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

        isLoading = false
    }
}

// MARK: - Кеш обложек (NSCache)

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 60 * 1024 * 1024
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        let bytes = image.jpegData(compressionQuality: 0.5)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: bytes)
    }
}

// MARK: - Основной экран YouTube Music 2026

struct YouTubeView: View {
    @ObservedObject var service = YouTubeService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared

    @State private var searchQuery = ""
    @State private var selectedTab = 0 // 0 = Чарты, 1 = Жанры, 2 = Подкасты, 3 = Аудиокниги, 4 = Поиск
    @State private var selectedGenre = "Pop"
    @State private var selectedPodcastCategory = "Популярные"
    @State private var selectedAudiobookCategory = "Бестселлеры"
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil

    private let podcastCategories = [
        ("🔥 Популярные", "Популярные"),
        ("🧠 Психология", "Психология"),
        ("💻 IT & Технологии", "IT Технологии"),
        ("📜 История & Мир", "История"),
        ("💼 Бизнес & Финансы", "Бизнес")
    ]

    private let audiobookCategories = [
        ("⭐ Бестселлеры", "Бестселлеры"),
        ("🚀 Фантастика & Фэнтези", "Фантастика"),
        ("🔍 Детективы & Триллеры", "Детективы"),
        ("📖 Классика", "Классика"),
        ("💡 Саморазвитие", "Саморазвитие")
    ]

    private let genres = [
        ("🔥 Поп", "Pop"),
        ("🎤 Хип-Хоп", "Hip-Hop"),
        ("⚡ Электроника", "Electronic"),
        ("🎸 Рок", "Rock"),
        ("☕ Chill Lofi", "Chill Lofi Beats"),
        ("🏋️ Тренировки", "Workout Beats")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Динамический фон
                AmbientBackgroundView(accentColor: AppTheme.neonPink, secondaryColor: AppTheme.neonCyan)

                VStack(spacing: 0) {
                    // Верхний Хедер & Поисковая строка
                    headerView
                    
                    // Переключатель секций (Liquid Glass)
                    sectionPickerView
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            if selectedTab == 0 {
                                trendingSection
                            } else if selectedTab == 1 {
                                categoriesSection
                            } else if selectedTab == 2 {
                                podcastsSection
                            } else if selectedTab == 3 {
                                audiobooksSection
                            } else {
                                searchResultsSection
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
        }
        .preferredColorScheme(.dark)
    }


    // MARK: - Хедер и Поисковая панель

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YouTube Music")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Тренды, чарты и быстрый поиск")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 44, height: 44)
                        .blur(radius: 6)
                    
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.6), radius: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Поисковая строка в стиле Liquid Glass
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.neonCyan)

                TextField("Исполнитель, трек, альбом...", text: $searchQuery)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .medium))
                    .submitLabel(.search)
                    .onSubmit { performSearch() }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        service.tracks = []
                        selectedTab = 0
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 16, opacity: 0.45)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Переключатель Вкладок

    private var sectionPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tabPickerButton(title: "🔥 Чарты", index: 0)
                tabPickerButton(title: "🎧 Жанры", index: 1)
                tabPickerButton(title: "🎙 Подкасты", index: 2)
                tabPickerButton(title: "📚 Аудиокниги", index: 3)
                if !service.tracks.isEmpty || !searchQuery.isEmpty {
                    tabPickerButton(title: "🔍 Результаты", index: 4)
                }
            }
            .padding(4)
        }
        .liquidGlass(cornerRadius: 18, opacity: 0.5)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }


    private func tabPickerButton(title: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                selectedTab = index
                HapticManager.shared.triggerSelection()
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(colors: [Color.red.opacity(0.8), AppTheme.neonPurple.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .neonGlow(color: .red, radius: 6, opacity: 0.4)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(SpringScaleButtonStyle())
    }

    // MARK: - Секция 1: Тренды и Топ-Чарты

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Музыкальные Чарты")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if service.isTrendingLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                }
            }
            .padding(.horizontal, 20)

            // Переключатель Региональных Чартов (Россия & СНГ, Global, USA, TikTok)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ChartRegion.allCases) { region in
                        let isSelected = service.selectedRegion == region
                        Button(action: {
                            HapticManager.shared.triggerSelection()
                            service.fetchTrendingMusic(region: region)
                        }) {
                            Text(region.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if isSelected {
                                            AppTheme.primaryGradient
                                                .clipShape(Capsule())
                                                .neonGlow(color: AppTheme.neonCyan, radius: 6, opacity: 0.4)
                                        } else {
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }


            // Горизонтальная карусель Чартов
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(service.trendingTracks.prefix(10)) { track in
                        chartCardView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Вертикальный список остальных трендовых композиций
            VStack(spacing: 10) {
                ForEach(service.trendingTracks.dropFirst(10)) { track in
                    trackRowView(for: track)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chartCardView(for track: YouTubeTrack) -> some View {
        let playerTrack = convertToPlayerTrack(track)
        let isPlayingThis = playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing

        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                YouTubeThumbnail(videoId: track.id, width: 150, height: 150)

                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playTrack(track)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.neonCyan)
                    }
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.uploader)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 18, opacity: 0.35)
        .onTapGesture {
            playTrack(track)
        }
    }

    // MARK: - Секция 2: Жанры и Категории

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Популярные Жанры")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            // Чипы жанров
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres, id: \.1) { name, key in
                        let isSelected = selectedGenre == key
                        Button(action: {
                            selectedGenre = key
                            HapticManager.shared.triggerSelection()
                            service.fetchCategoryMusic(genre: key)
                        }) {
                            Text(name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if isSelected {
                                            AppTheme.primaryGradient
                                                .clipShape(Capsule())
                                                .neonGlow(color: AppTheme.neonCyan, radius: 6, opacity: 0.4)
                                        } else {
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Список треков выбранной категории
            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.categoryTracks) { track in
                        trackRowView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }
    // MARK: - Секция 3: Подкасты

    private var podcastsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎙 Подкасты")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(podcastCategories, id: \.1) { name, key in
                        let isSelected = selectedPodcastCategory == key
                        Button(action: {
                            selectedPodcastCategory = key
                            HapticManager.shared.triggerSelection()
                            service.fetchPodcasts(category: key)
                        }) {
                            Text(name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if isSelected {
                                            AppTheme.accentGradient
                                                .clipShape(Capsule())
                                                .neonGlow(color: AppTheme.neonPurple, radius: 6, opacity: 0.4)
                                        } else {
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonPurple))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if service.podcastTracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Нажмите на категорию подкастов для выгрузки")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.podcastTracks) { track in
                        trackRowView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            if service.podcastTracks.isEmpty {
                service.fetchPodcasts(category: "Популярные")
            }
        }
    }

    // MARK: - Секция 4: Аудиокниги

    private var audiobooksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📚 Аудиокниги")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(audiobookCategories, id: \.1) { name, key in
                        let isSelected = selectedAudiobookCategory == key
                        Button(action: {
                            selectedAudiobookCategory = key
                            HapticManager.shared.triggerSelection()
                            service.fetchAudiobooks(category: key)
                        }) {
                            Text(name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if isSelected {
                                            AppTheme.primaryGradient
                                                .clipShape(Capsule())
                                                .neonGlow(color: AppTheme.neonCyan, radius: 6, opacity: 0.4)
                                        } else {
                                            Capsule()
                                                .fill(Color.white.opacity(0.06))
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if service.audiobookTracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Нажмите на жанр аудиокниг для выгрузки релиза")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.audiobookTracks) { track in
                        trackRowView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            if service.audiobookTracks.isEmpty {
                service.fetchAudiobooks(category: "Бестселлеры")
            }
        }
    }

    // MARK: - Секция 5: Результаты поиска


    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты поиска")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            if service.isLoading && service.tracks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if service.tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Введите название трека или исполнителя")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.tracks) { track in
                        trackRowView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Строка трека (Track Row)

    private func trackRowView(for track: YouTubeTrack) -> some View {
        let playerTrack = convertToPlayerTrack(track)
        let isPlayingThis = playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing
        let isDownloaded = downloadManager.isDownloaded(trackId: track.id)

        return HStack(spacing: 12) {
            ZStack {
                YouTubeThumbnail(videoId: track.id, width: 52, height: 52)

                if isPlayingThis {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 52, height: 52)
                        
                        MiniVisualizerView(isPlaying: true, tintColor: AppTheme.neonCyan)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(track.uploader)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)

                    if track.duration > 0 {
                        Text("•")
                            .foregroundColor(AppTheme.textMuted)
                        Text(formatDuration(track.duration))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }

            Spacer()

            // Действия: Скачивание / Плейлист
            HStack(spacing: 12) {
                // Скачивание
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    if !isDownloaded {
                        downloadManager.downloadYouTubeTrack(track)
                    }
                }) {
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(isDownloaded ? .green : AppTheme.textSecondary)
                }


                // Добавление в плейлист
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .light)
                    selectedTrackForPlaylist = playerTrack.toPlaylistTrack()
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .liquidGlass(cornerRadius: 16, opacity: 0.35)
        .onTapGesture {
            playTrack(track)
        }
    }

    // MARK: - Вспомогательные функции

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        selectedTab = 2
        service.search(query: searchQuery)
    }

    private func playTrack(_ track: YouTubeTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        let playerTrack = convertToPlayerTrack(track)
        
        let tracksSource: [YouTubeTrack]
        switch selectedTab {
        case 0: tracksSource = service.trendingTracks
        case 1: tracksSource = service.categoryTracks
        case 2: tracksSource = service.podcastTracks
        case 3: tracksSource = service.audiobookTracks
        default: tracksSource = service.tracks
        }
        
        let allCurrent = tracksSource.map { convertToPlayerTrack($0) }
        playerManager.play(track: playerTrack, in: allCurrent)
    }



    private func convertToPlayerTrack(_ track: YouTubeTrack) -> PlayerTrack {
        PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.uploader,
            sourceName: "YouTube Music",
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: nil,
            duration: Double(track.duration)
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
