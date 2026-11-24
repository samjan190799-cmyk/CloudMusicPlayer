import SwiftUI

/// Главная: приветствие, быстрые подборки, «Продолжить слушать», плейлисты и новинки
struct HomeView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var playlists = PlaylistManager.shared
    @ObservedObject private var history = ListeningHistory.shared
    @ObservedObject private var status = PlaybackStatus.shared
    @ObservedObject private var artwork = NowPlayingArtwork.shared
    @AppStorage("dynamicPlayerColor") private var dynamicColor = true

    @State private var showCreatePlaylist = false
    @State private var showImporter = false

    private var library: [LocalTrack] {
        store.tracks
    }

    private var favorites: Playlist? {
        playlists.playlists.first(where: { $0.id == PlaylistManager.favoritesUUID })
    }

    var body: some View {
        NavigationStack {
            let allTracks = library

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    header(trackCount: allTracks.count)

                    quickTiles(library: allTracks)

                    if allTracks.isEmpty && history.entries.isEmpty {
                        onboarding
                    }

                    recentSection

                    playlistsSection

                    topSection

                    newInLibrarySection(allTracks)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground(glow: status.hasTrack && dynamicColor ? artwork.color : nil))
            .hiddenNavigationBar()
            .createPlaylistAlert(isPresented: $showCreatePlaylist)
            .sheet(isPresented: $showImporter) {
                AudioDocumentPicker { urls in
                    DeviceMediaScanner.shared.importFiles(from: urls)
                    AppRouter.shared.showToast("Импортируем \(Formatters.tracks(urls.count))", icon: "square.and.arrow.down.fill")
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Шапка

    private func header(trackCount: Int) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.appLargeTitle)
                    .foregroundColor(Palette.textPrimary)
                Text(trackCount > 0 ? "В медиатеке \(Formatters.tracks(trackCount))" : "Ваша музыка — без подписок")
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            CircleIconButton(systemName: "gearshape.fill", size: 40, iconSize: 17) {
                AppRouter.shared.isSettingsPresented = true
            }
            .accessibilityLabel("Настройки")
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<17: return "Добрый день"
        case 17..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    // MARK: - Быстрые плитки

    private func quickTiles(library: [LocalTrack]) -> some View {
        let favoriteTracks = favorites?.tracks ?? []
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            if let favorites = favorites {
                NavigationLink {
                    PlaylistDetailView(playlistID: favorites.id)
                } label: {
                    QuickTile(
                        title: "Избранное",
                        subtitle: Formatters.tracks(favoriteTracks.count),
                        icon: "heart.fill",
                        colors: [Color(red: 1.0, green: 0.36, blue: 0.48), Color(red: 0.42, green: 0.16, blue: 0.62)]
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Button {
                let mix = Mixes.dailyMix(library: library, favorites: favoriteTracks, history: history)
                guard !mix.isEmpty else {
                    AppRouter.shared.showToast("Добавьте музыку, чтобы собрать микс", icon: "sparkles")
                    return
                }
                HapticManager.shared.triggerImpact(style: .medium)
                AudioPlayerManager.shared.playInOrder(mix)
            } label: {
                QuickTile(
                    title: "Микс дня",
                    subtitle: "Новый каждый день",
                    icon: "sparkles",
                    colors: [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.2, green: 0.1, blue: 0.5)]
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                guard !library.isEmpty else {
                    AppRouter.shared.showToast("Медиатека пока пуста", icon: "music.note")
                    return
                }
                HapticManager.shared.triggerImpact(style: .medium)
                AudioPlayerManager.shared.playShuffled(library.map { $0.toPlayerTrack() })
            } label: {
                QuickTile(
                    title: "Перемешать всё",
                    subtitle: Formatters.tracks(library.count),
                    icon: "shuffle",
                    colors: [Color(red: 1.0, green: 0.62, blue: 0.25), Color(red: 0.55, green: 0.16, blue: 0.12)]
                )
            }
            .buttonStyle(PressableButtonStyle())

            NavigationLink {
                DownloadsView()
            } label: {
                DownloadsQuickTile()
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    // MARK: - Первый запуск

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("С чего начать")
                .font(.appTitle)
                .foregroundColor(Palette.textPrimary)

            OnboardingRow(icon: "magnifyingglass", title: "Найдите музыку", subtitle: "Поиск по YouTube, чарты, подкасты и аудиокниги") {
                AppRouter.shared.select(.search)
            }
            OnboardingRow(icon: "cloud.fill", title: "Подключите облако", subtitle: "Google Диск, Яндекс Диск или Telegram") {
                AppRouter.shared.select(.cloud)
            }
            OnboardingRow(icon: "square.and.arrow.down.fill", title: "Импортируйте файлы", subtitle: "MP3, M4A, FLAC и другие из приложения «Файлы»") {
                showImporter = true
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    // MARK: - Продолжить слушать

    @ViewBuilder
    private var recentSection: some View {
        let recent = history.recentTracks(limit: 15)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Продолжить слушать")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, track in
                            let display = track.display
                            Button {
                                AudioPlayerManager.shared.play(
                                    track: track.toPlayerTrack(),
                                    in: recent.map { $0.toPlayerTrack() }
                                )
                            } label: {
                                MediaCard(
                                    artwork: track.artworkKey,
                                    title: display.title,
                                    subtitle: display.artist,
                                    isCurrent: status.isCurrent(track.id),
                                    isPlaying: status.isPlayingTrack(track.id)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .contextMenu {
                                TrackMenuItems(track: track.toPlayerTrack())
                            }
                            .accessibilityHint("Трек \(index + 1)")
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    // MARK: - Плейлисты

    private var playlistsSection: some View {
        let userPlaylists = playlists.playlists.filter { $0.id != PlaylistManager.favoritesUUID }

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Ваши плейлисты",
                actionTitle: userPlaylists.isEmpty ? nil : "Все",
                action: userPlaylists.isEmpty ? nil : { AppRouter.shared.select(.library) }
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(userPlaylists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            PlaylistCard(playlist: playlist)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                    Button {
                        showCreatePlaylist = true
                    } label: {
                        NewPlaylistCard()
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
        }
    }

    // MARK: - Часто слушаете

    @ViewBuilder
    private var topSection: some View {
        let top = history.topTracks(limit: 5)
        if top.count >= 3 {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Часто слушаете")
                VStack(spacing: 2) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, track in
                        let display = track.display
                        Button {
                            AudioPlayerManager.shared.play(track: track.toPlayerTrack(), in: top.map { $0.toPlayerTrack() })
                        } label: {
                            TrackRow(
                                artwork: track.artworkKey,
                                title: display.title,
                                subtitle: display.artist,
                                isCurrent: status.isCurrent(track.id),
                                isPlaying: status.isPlayingTrack(track.id),
                                number: index + 1
                            ) {
                                Menu {
                                    TrackMenuItems(track: track.toPlayerTrack())
                                } label: {
                                    MoreMenuLabel()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
        }
    }

    // MARK: - Новое в медиатеке

    @ViewBuilder
    private func newInLibrarySection(_ allTracks: [LocalTrack]) -> some View {
        let newest = Array(allTracks.sorted { $0.addedAt > $1.addedAt }.prefix(12))
        if !newest.isEmpty {
            let queue = newest.map { $0.toPlayerTrack() }
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Новое в медиатеке", actionTitle: "Все") {
                    AppRouter.shared.select(.library)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(newest.enumerated()), id: \.element.id) { index, track in
                            let display = track.display
                            Button {
                                AudioPlayerManager.shared.play(track: queue[index], in: queue)
                            } label: {
                                MediaCard(
                                    artwork: track.artworkKey,
                                    title: display.title,
                                    subtitle: display.artist,
                                    isCurrent: status.isCurrent(track.id),
                                    isPlaying: status.isPlayingTrack(track.id)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .contextMenu {
                                TrackMenuItems(track: queue[index])
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }
}

// MARK: - Плитка быстрого доступа

private struct QuickTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surface)
        )
    }
}

/// Плитка «Скачанное» — отдельная вью, чтобы прогресс загрузок не перерисовывал всю главную
private struct DownloadsQuickTile: View {
    @ObservedObject private var downloads = DownloadManager.shared

    var body: some View {
        QuickTile(
            title: "Скачанное",
            subtitle: downloads.activeDownloads.isEmpty
                ? Formatters.tracks(downloads.localTracks.count)
                : "Загружается: \(downloads.activeDownloads.count)",
            icon: "arrow.down.circle.fill",
            colors: [Color(red: 0.2, green: 0.82, blue: 0.62), Color(red: 0.04, green: 0.3, blue: 0.35)]
        )
    }
}

// MARK: - Строка онбординга

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appRowTitle)
                        .foregroundColor(Palette.textPrimary)
                    Text(subtitle)
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textTertiary)
            }
            .padding(14)
            .cardBackground()
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }
}
