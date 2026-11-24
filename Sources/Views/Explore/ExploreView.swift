import SwiftUI

/// Разделы обзора онлайн-музыки
enum BrowseCategory: String, CaseIterable, Identifiable {
    case charts
    case genres
    case podcasts
    case audiobooks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .charts: return "Чарты"
        case .genres: return "Жанры"
        case .podcasts: return "Подкасты"
        case .audiobooks: return "Аудиокниги"
        }
    }
}

/// Поиск по всему (медиатека, плейлисты, облако, YouTube) и обзор чартов, жанров, подкастов и аудиокниг
struct ExploreView: View {
    @ObservedObject private var service = YouTubeService.shared
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var playlists = PlaylistManager.shared
    @ObservedObject private var google = GoogleDriveService.shared
    @ObservedObject private var yandex = YandexDiskService.shared
    @ObservedObject private var telegram = TelegramService.shared
    @ObservedObject private var status = PlaybackStatus.shared

    @State private var query = ""
    @State private var category: BrowseCategory = .charts
    @State private var selectedGenre = Genre.all[0]
    @State private var podcastCategory = "Популярные"
    @State private var audiobookCategory = "Бестселлеры"

    private let podcastCategories = ["Популярные", "Психология", "IT Технологии", "История", "Бизнес"]
    private let audiobookCategories = ["Бестселлеры", "Фантастика", "Детективы", "Классика", "Саморазвитие", "Бизнес"]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Поиск")
                        .font(.appLargeTitle)
                        .foregroundColor(Palette.textPrimary)
                        .padding(.horizontal, Metrics.screenPadding)

                    SearchField(text: $query, placeholder: "Треки, исполнители, подкасты") {
                        if trimmedQuery.count >= 2 {
                            service.search(query: trimmedQuery)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)

                    if trimmedQuery.isEmpty {
                        browseContent
                    } else {
                        searchResults
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(AppBackground())
            .hiddenNavigationBar()
            .task(id: trimmedQuery) {
                let current = trimmedQuery
                guard current.count >= 2 else { return }
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled else { return }
                service.search(query: current)
            }
        }
    }

    // MARK: - Обзор

    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BrowseCategory.allCases) { item in
                        ChipButton(title: item.title, isSelected: category == item) {
                            category = item
                            loadCategoryIfNeeded(item)
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }

            switch category {
            case .charts:
                chartsSection
            case .genres:
                genresSection
            case .podcasts:
                podcastsSection
            case .audiobooks:
                audiobooksSection
            }
        }
        .onAppear {
            loadCategoryIfNeeded(category)
        }
    }

    private func loadCategoryIfNeeded(_ item: BrowseCategory) {
        switch item {
        case .charts:
            if service.trendingTracks.isEmpty && !service.isTrendingLoading {
                service.fetchTrendingMusic()
            }
        case .genres:
            if service.categoryTracks.isEmpty {
                service.fetchCategoryMusic(genre: selectedGenre.query)
            }
        case .podcasts:
            if service.podcastTracks.isEmpty {
                service.fetchPodcasts(category: podcastCategory)
            }
        case .audiobooks:
            if service.audiobookTracks.isEmpty {
                service.fetchAudiobooks(category: audiobookCategory)
            }
        }
    }

    // MARK: Чарты

    private var chartsSection: some View {
        let tracks = service.trendingTracks
        let queue = tracks.map { youTubePlayerTrack($0) }

        return VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChartRegion.allCases) { region in
                        ChipButton(title: region.title, isSelected: service.selectedRegion == region) {
                            service.fetchTrendingMusic(region: region)
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }

            if tracks.isEmpty {
                loadingOrEmpty(isLoading: service.isTrendingLoading, message: "Не удалось загрузить чарт. Потяните позже или выберите другой регион.")
            } else {
                SectionHeader(title: "Топ недели", subtitle: service.selectedRegion.title)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(tracks.prefix(8).enumerated()), id: \.element.id) { index, track in
                            Button {
                                play(queue[index], in: queue)
                            } label: {
                                ChartCard(
                                    track: track,
                                    rank: index + 1,
                                    isCurrent: status.isCurrent(track.id),
                                    isPlaying: status.isPlayingTrack(track.id)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .contextMenu {
                                onlineMenu(for: track, playerTrack: queue[index])
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }

                if tracks.count > 8 {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(tracks.enumerated().dropFirst(8)), id: \.element.id) { index, track in
                            onlineRow(track, playerTrack: queue[index], number: index + 1) {
                                play(queue[index], in: queue)
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    // MARK: Жанры

    private var genresSection: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let tracks = service.categoryTracks
        let queue = tracks.map { youTubePlayerTrack($0) }

        return VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Genre.all) { genre in
                    Button {
                        selectedGenre = genre
                        service.fetchCategoryMusic(genre: genre.query)
                    } label: {
                        GenreTile(genre: genre, isSelected: selectedGenre == genre)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, Metrics.screenPadding)

            SectionHeader(title: selectedGenre.title)

            if tracks.isEmpty {
                loadingOrEmpty(isLoading: service.isLoading, message: "Здесь появятся треки выбранного жанра.")
            } else {
                trackList(tracks, queue: queue)
            }
        }
    }

    // MARK: Подкасты

    private var podcastsSection: some View {
        let tracks = service.podcastTracks
        let queue = tracks.map { youTubePlayerTrack($0) }

        return VStack(alignment: .leading, spacing: 18) {
            categoryChips(podcastCategories, selected: podcastCategory) { value in
                podcastCategory = value
                service.fetchPodcasts(category: value)
            }

            if tracks.isEmpty {
                loadingOrEmpty(isLoading: service.isLoading, message: "Выберите тему, чтобы найти выпуски.")
            } else {
                trackList(tracks, queue: queue, showsDuration: true)
            }
        }
    }

    // MARK: Аудиокниги

    private var audiobooksSection: some View {
        let tracks = service.audiobookTracks
        let queue = tracks.map { youTubePlayerTrack($0, sourceName: "Аудиокниги") }

        return VStack(alignment: .leading, spacing: 18) {
            categoryChips(audiobookCategories, selected: audiobookCategory) { value in
                audiobookCategory = value
                service.fetchAudiobooks(category: value)
            }

            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                Text("Место остановки сохраняется автоматически")
            }
            .font(.appCaption)
            .foregroundColor(Palette.textSecondary)
            .padding(.horizontal, Metrics.screenPadding)

            if tracks.isEmpty {
                loadingOrEmpty(isLoading: service.isLoading, message: "Выберите жанр, чтобы найти книги.")
            } else {
                trackList(tracks, queue: queue, showsDuration: true)
            }
        }
    }

    // MARK: - Результаты поиска

    private var searchResults: some View {
        let localMatches = matchingLibraryTracks()
        let playlistMatches = playlists.playlists.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
        let googleMatches = google.tracks.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }.prefix(5)
        let yandexMatches = yandex.tracks.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }.prefix(5)
        let telegramMatches = telegram.tracks.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || ($0.performer?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }.prefix(5)

        return VStack(alignment: .leading, spacing: 26) {
            if !localMatches.isEmpty {
                let queue = localMatches.map { $0.toPlayerTrack() }
                resultsBlock(title: "В медиатеке") {
                    ForEach(Array(localMatches.enumerated()), id: \.element.id) { index, track in
                        Button {
                            play(queue[index], in: queue)
                        } label: {
                            TrackRow(
                                artwork: track.artworkKey,
                                title: track.display.title,
                                subtitle: track.display.artist,
                                isCurrent: status.isCurrent(track.id),
                                isPlaying: status.isPlayingTrack(track.id)
                            ) {
                                Menu {
                                    TrackMenuItems(track: queue[index])
                                } label: {
                                    MoreMenuLabel()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !playlistMatches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Плейлисты")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(playlistMatches) { playlist in
                                NavigationLink {
                                    PlaylistDetailView(playlistID: playlist.id)
                                } label: {
                                    PlaylistCard(playlist: playlist, width: 128)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                    }
                }
            }

            if !googleMatches.isEmpty || !yandexMatches.isEmpty || !telegramMatches.isEmpty {
                resultsBlock(title: "В облаке") {
                    ForEach(Array(googleMatches), id: \.id) { track in
                        cloudResultRow(CloudTracks.playerTrack(track), source: "Google Диск") {
                            let queue = googleMatches.map { CloudTracks.playerTrack($0) }
                            play(CloudTracks.playerTrack(track), in: queue)
                        }
                    }
                    ForEach(Array(yandexMatches), id: \.id) { track in
                        cloudResultRow(CloudTracks.playerTrack(track), source: "Яндекс Диск") {
                            let queue = yandexMatches.map { CloudTracks.playerTrack($0) }
                            play(CloudTracks.playerTrack(track), in: queue)
                        }
                    }
                    ForEach(Array(telegramMatches), id: \.id) { track in
                        let display = CloudTracks.display(track)
                        Button {
                            CloudTracks.playTelegram(track)
                        } label: {
                            TrackRow(
                                artwork: CloudTracks.artworkKey(track),
                                title: display.title,
                                subtitle: "Telegram · \(display.artist)",
                                isCurrent: status.isCurrent("tg_\(track.id)"),
                                isPlaying: status.isPlayingTrack("tg_\(track.id)")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            youTubeResults
        }
    }

    private var youTubeResults: some View {
        let tracks = service.tracks
        let queue = tracks.map { youTubePlayerTrack($0) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "YouTube")
                if service.isLoading {
                    ProgressView()
                        .padding(.trailing, Metrics.screenPadding)
                }
            }

            if tracks.isEmpty {
                if let error = service.errorMessage, !service.isLoading {
                    Text(error)
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                        .padding(.horizontal, Metrics.screenPadding)
                } else if !service.isLoading {
                    Text("Нажмите «Найти» на клавиатуре, чтобы искать онлайн")
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                        .padding(.horizontal, Metrics.screenPadding)
                }
            } else {
                trackList(tracks, queue: queue, showsDuration: true)

                if service.canLoadMore {
                    Button {
                        service.loadMore()
                    } label: {
                        HStack {
                            if service.isLoading {
                                ProgressView()
                            }
                            Text("Показать ещё")
                        }
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                    .padding(.horizontal, Metrics.screenPadding)
                    .disabled(service.isLoading)
                }
            }
        }
    }

    private func matchingLibraryTracks() -> [LocalTrack] {
        let matches = store.tracks.filter { track in
            let display = track.display
            return display.title.localizedCaseInsensitiveContains(trimmedQuery)
                || display.artist.localizedCaseInsensitiveContains(trimmedQuery)
        }
        return Array(matches.prefix(6))
    }

    private func resultsBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            LazyVStack(spacing: 2) {
                content()
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private func cloudResultRow(_ track: PlayerTrack, source: String, onPlay: @escaping () -> Void) -> some View {
        Button(action: onPlay) {
            TrackRow(
                artwork: track.artworkKey,
                title: track.display.title,
                subtitle: "\(source) · \(track.display.artist)",
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id)
            ) {
                Menu {
                    TrackMenuItems(
                        track: track,
                        onDownload: TrackActions.canDownload(track) ? { _ = TrackActions.download(track) } : nil
                    )
                } label: {
                    MoreMenuLabel()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Общие куски

    private func trackList(_ tracks: [YouTubeTrack], queue: [PlayerTrack], showsDuration: Bool = false) -> some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                onlineRow(track, playerTrack: queue[index], showsDuration: showsDuration) {
                    play(queue[index], in: queue)
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private func onlineRow(
        _ track: YouTubeTrack,
        playerTrack: PlayerTrack,
        number: Int? = nil,
        showsDuration: Bool = true,
        onPlay: @escaping () -> Void
    ) -> some View {
        let display = track.display
        let subtitle = showsDuration && track.duration > 0
            ? "\(display.artist) · \(Formatters.time(Double(track.duration)))"
            : display.artist

        return Button(action: onPlay) {
            TrackRow(
                artwork: track.artworkKey,
                title: display.title,
                subtitle: subtitle,
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id),
                number: number
            ) {
                HStack(spacing: 0) {
                    LiveDownloadButton(trackID: track.id) {
                        HapticManager.shared.triggerImpact(style: .light)
                        DownloadManager.shared.downloadYouTubeTrack(track)
                    }
                    Menu {
                        onlineMenu(for: track, playerTrack: playerTrack)
                    } label: {
                        MoreMenuLabel()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            onlineMenu(for: track, playerTrack: playerTrack)
        }
    }

    private func onlineMenu(for track: YouTubeTrack, playerTrack: PlayerTrack) -> some View {
        let downloads = DownloadManager.shared
        var download: (() -> Void)? = nil
        if !downloads.isDownloaded(trackId: track.id) && downloads.activeDownloads[track.id] == nil {
            download = {
                downloads.downloadYouTubeTrack(track)
                AppRouter.shared.showToast("Загрузка началась", icon: "arrow.down.circle.fill")
            }
        }
        return TrackMenuItems(track: playerTrack, onDownload: download)
    }

    private func categoryChips(_ values: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    ChipButton(title: value, isSelected: selected == value) {
                        onSelect(value)
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    @ViewBuilder
    private func loadingOrEmpty(isLoading: Bool, message: String) -> some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 40)
                Spacer()
            }
        } else {
            Text(message)
                .font(.appSubheadline)
                .foregroundColor(Palette.textSecondary)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 20)
        }
    }

    private func youTubePlayerTrack(_ track: YouTubeTrack, sourceName: String = "YouTube Music") -> PlayerTrack {
        PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.uploader,
            sourceName: sourceName,
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: nil,
            duration: track.duration > 0 ? Double(track.duration) : nil
        )
    }

    private func play(_ track: PlayerTrack, in queue: [PlayerTrack]) {
        HapticManager.shared.triggerImpact(style: .medium)
        AudioPlayerManager.shared.play(track: track, in: queue)
    }
}

// MARK: - Жанры

struct Genre: Identifiable, Equatable {
    let title: String
    let query: String
    let icon: String
    let colors: [Color]

    var id: String { query }

    static let all: [Genre] = [
        Genre(title: "Поп", query: "Pop", icon: "sparkles", colors: [Color(red: 1.0, green: 0.38, blue: 0.55), Color(red: 0.55, green: 0.12, blue: 0.45)]),
        Genre(title: "Хип-хоп", query: "Hip-Hop", icon: "music.mic", colors: [Color(red: 1.0, green: 0.62, blue: 0.22), Color(red: 0.5, green: 0.16, blue: 0.1)]),
        Genre(title: "Электроника", query: "Electronic", icon: "waveform", colors: [Color(red: 0.3, green: 0.65, blue: 1.0), Color(red: 0.12, green: 0.1, blue: 0.48)]),
        Genre(title: "Рок", query: "Rock", icon: "guitars.fill", colors: [Color(red: 0.95, green: 0.3, blue: 0.3), Color(red: 0.25, green: 0.05, blue: 0.08)]),
        Genre(title: "Чилл и lo-fi", query: "Chill Lofi Beats", icon: "cup.and.saucer.fill", colors: [Color(red: 0.4, green: 0.85, blue: 0.7), Color(red: 0.06, green: 0.3, blue: 0.35)]),
        Genre(title: "Для тренировки", query: "Workout Beats", icon: "figure.run", colors: [Color(red: 0.7, green: 0.5, blue: 1.0), Color(red: 0.25, green: 0.08, blue: 0.45)])
    ]

    static func == (lhs: Genre, rhs: Genre) -> Bool {
        lhs.query == rhs.query
    }
}

private struct GenreTile: View {
    let genre: Genre
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: genre.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: genre.icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white.opacity(0.25))
                .rotationEffect(.degrees(-14))
                .offset(x: 12, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            Text(genre.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
        }
        .frame(height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
        )
    }
}

// MARK: - Карточка чарта

private struct ChartCard: View {
    let track: YouTubeTrack
    let rank: Int
    let isCurrent: Bool
    let isPlaying: Bool

    @Environment(\.accent) private var accent

    var body: some View {
        let display = track.display

        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ArtworkView(artwork: track.artworkKey, cornerRadius: 12, maxPixel: 500)
                    .frame(width: 168, height: 168)

                LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(alignment: .bottom) {
                    Text("\(rank)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.4), radius: 6)
                    Spacer()
                    if isCurrent {
                        PlayingBars(isAnimating: isPlaying, color: .black, height: 14)
                            .padding(7)
                            .background(Circle().fill(accent))
                    }
                }
                .padding(10)
            }
            .frame(width: 168, height: 168)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrent ? accent : Palette.textPrimary)
                    .lineLimit(1)
                Text(display.artist)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 168, alignment: .leading)
    }
}
