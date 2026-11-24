import SwiftUI

/// Сортировка песен в медиатеке
enum LibrarySort: String, CaseIterable, Identifiable {
    case recent
    case title
    case artist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Недавно добавленные"
        case .title: return "По названию"
        case .artist: return "По исполнителю"
        }
    }
}

/// Разделы медиатеки
enum LibrarySection: String, CaseIterable, Identifiable {
    case songs
    case artists
    case playlists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: return "Песни"
        case .artists: return "Исполнители"
        case .playlists: return "Плейлисты"
        }
    }
}

/// Медиатека: вся локальная музыка, исполнители и плейлисты
struct LibraryView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var scanner = DeviceMediaScanner.shared
    @ObservedObject private var playlists = PlaylistManager.shared
    @ObservedObject private var status = PlaybackStatus.shared

    @AppStorage("librarySort") private var sortRaw = LibrarySort.recent.rawValue
    @State private var section: LibrarySection = .songs
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var showCreatePlaylist = false

    private var sort: LibrarySort {
        LibrarySort(rawValue: sortRaw) ?? .recent
    }

    private var allTracks: [LocalTrack] {
        store.tracks
    }

    var body: some View {
        NavigationStack {
            let tracks = allTracks

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    sectionPicker

                    switch section {
                    case .songs:
                        songsSection(tracks)
                    case .artists:
                        artistsSection(tracks)
                    case .playlists:
                        playlistsSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
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

    private var header: some View {
        HStack {
            Text("Медиатека")
                .font(.appLargeTitle)
                .foregroundColor(Palette.textPrimary)

            if scanner.isScanning {
                ProgressView()
                    .padding(.leading, 6)
            }

            Spacer()

            Menu {
                Button {
                    showImporter = true
                } label: {
                    Label("Импортировать файлы", systemImage: "square.and.arrow.down")
                }
                Button {
                    DeviceMediaScanner.shared.requestAndScanAppleMusic()
                    DeviceMediaScanner.shared.scanFilesAppDocuments()
                    AppRouter.shared.showToast("Ищем музыку на iPhone…", icon: "iphone")
                } label: {
                    Label("Найти музыку на iPhone", systemImage: "iphone")
                }
                Divider()
                Button {
                    showCreatePlaylist = true
                } label: {
                    Label("Новый плейлист", systemImage: "music.note.list")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.surfaceStrong))
            }
            .accessibilityLabel("Добавить")

            CircleIconButton(systemName: "gearshape.fill", size: 40, iconSize: 17) {
                AppRouter.shared.isSettingsPresented = true
            }
            .accessibilityLabel("Настройки")
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { item in
                    ChipButton(title: item.title, isSelected: section == item) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            section = item
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    // MARK: - Песни

    private func filteredSorted(_ tracks: [LocalTrack]) -> [LocalTrack] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered: [LocalTrack]
        if query.isEmpty {
            filtered = tracks
        } else {
            filtered = tracks.filter { track in
                let display = track.display
                return display.title.localizedCaseInsensitiveContains(query)
                    || display.artist.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .recent:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .title:
            return filtered.sorted {
                $0.display.title.localizedCaseInsensitiveCompare($1.display.title) == .orderedAscending
            }
        case .artist:
            return filtered.sorted {
                let lhs = $0.display
                let rhs = $1.display
                if lhs.artist == rhs.artist {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) == .orderedAscending
            }
        }
    }

    @ViewBuilder
    private func songsSection(_ tracks: [LocalTrack]) -> some View {
        if tracks.isEmpty {
            EmptyStateView(
                icon: "music.note.house.fill",
                title: "Медиатека пуста",
                message: "Импортируйте файлы, скачайте треки из облака или найдите музыку в поиске — всё появится здесь.",
                actionTitle: "Импортировать файлы"
            ) {
                showImporter = true
            }
        } else {
            let visible = filteredSorted(tracks)
            let queue = visible.map { $0.toPlayerTrack() }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SearchField(text: $searchText, placeholder: "Поиск в медиатеке")
                    sortMenu
                }
                .padding(.horizontal, Metrics.screenPadding)

                if searchText.isEmpty {
                    PlayShuffleButtons {
                        AudioPlayerManager.shared.playInOrder(queue)
                    } onShuffle: {
                        AudioPlayerManager.shared.playShuffled(queue)
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }

                Text(Formatters.tracks(visible.count))
                    .font(.appCaption)
                    .foregroundColor(Palette.textTertiary)
                    .padding(.horizontal, Metrics.screenPadding)

                if visible.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Ничего не найдено",
                        message: "Попробуйте другое название или исполнителя."
                    )
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, track in
                            libraryRow(track: track, playerTrack: queue[index]) {
                                AudioPlayerManager.shared.play(track: queue[index], in: queue)
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Сортировка", selection: $sortRaw) {
                ForEach(LibrarySort.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surfaceStrong))
        }
        .accessibilityLabel("Сортировка")
    }

    private func libraryRow(track: LocalTrack, playerTrack: PlayerTrack, onPlay: @escaping () -> Void) -> some View {
        let display = track.display
        let isDownloaded = DownloadManager.shared.isDownloaded(trackId: track.id)
        let isDeviceMusic = track.relativePath.hasPrefix("ipod-library://")

        return Button(action: onPlay) {
            TrackRow(
                artwork: track.artworkKey,
                title: display.title,
                subtitle: display.artist,
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id)
            ) {
                Menu {
                    TrackMenuItems(
                        track: playerTrack,
                        onDelete: isDeviceMusic ? nil : { delete(track, isDownloaded: isDownloaded) }
                    )
                } label: {
                    MoreMenuLabel()
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            TrackMenuItems(
                track: playerTrack,
                onDelete: isDeviceMusic ? nil : { delete(track, isDownloaded: isDownloaded) }
            )
        }
    }

    private func delete(_ track: LocalTrack, isDownloaded: Bool) {
        withAnimation {
            if isDownloaded {
                DownloadManager.shared.deleteTrack(trackId: track.id)
            } else {
                scanner.removeTrack(track)
            }
        }
        HapticManager.shared.triggerNotification(type: .success)
        AppRouter.shared.showToast("Трек удалён", icon: "trash.fill")
    }

    // MARK: - Исполнители

    @ViewBuilder
    private func artistsSection(_ tracks: [LocalTrack]) -> some View {
        let artists = ArtistGroup.make(from: tracks)
        if artists.isEmpty {
            EmptyStateView(
                icon: "music.mic",
                title: "Пока нет исполнителей",
                message: "Они появятся, когда в медиатеке будет музыка."
            )
        } else {
            let columns = [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(artists) { artist in
                    NavigationLink {
                        ArtistDetailView(artist: artist)
                    } label: {
                        ArtistCell(artist: artist)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    // MARK: - Плейлисты

    private var playlistsSection: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            Button {
                showCreatePlaylist = true
            } label: {
                GeometryReader { proxy in
                    NewPlaylistCard(width: proxy.size.width)
                }
                .aspectRatio(0.78, contentMode: .fit)
            }
            .buttonStyle(PressableButtonStyle())

            ForEach(playlists.playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlistID: playlist.id)
                } label: {
                    GeometryReader { proxy in
                        PlaylistCard(playlist: playlist, width: proxy.size.width)
                    }
                    .aspectRatio(0.78, contentMode: .fit)
                }
                .buttonStyle(PressableButtonStyle())
                .contextMenu {
                    if playlist.id != PlaylistManager.favoritesUUID {
                        Button(role: .destructive) {
                            playlists.deletePlaylist(id: playlist.id)
                        } label: {
                            Label("Удалить плейлист", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }
}

// MARK: - Исполнители

struct ArtistGroup: Identifiable {
    let name: String
    let tracks: [LocalTrack]

    var id: String { name }

    static func make(from tracks: [LocalTrack]) -> [ArtistGroup] {
        var groups: [String: [LocalTrack]] = [:]
        for track in tracks {
            groups[track.display.artist, default: []].append(track)
        }
        return groups
            .map { ArtistGroup(name: $0.key, tracks: $0.value.sorted { $0.addedAt > $1.addedAt }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct ArtistCell: View {
    let artist: ArtistGroup

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    if let cover = artist.tracks.first(where: { $0.localCoverPath != nil }) ?? artist.tracks.first {
                        ArtworkView(artwork: cover.artworkKey, cornerRadius: proxy.size.width / 2, maxPixel: 240)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .clipShape(Circle())
            }
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(Formatters.tracks(artist.tracks.count))
                    .font(.system(size: 12))
                    .foregroundColor(Palette.textSecondary)
            }
        }
    }
}

/// Страница исполнителя
struct ArtistDetailView: View {
    let artist: ArtistGroup
    @ObservedObject private var status = PlaybackStatus.shared

    var body: some View {
        let queue = artist.tracks.map { $0.toPlayerTrack() }

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    if let cover = artist.tracks.first(where: { $0.localCoverPath != nil }) ?? artist.tracks.first {
                        ArtworkView(artwork: cover.artworkKey, cornerRadius: 90, maxPixel: 540)
                            .frame(width: 180, height: 180)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
                    }
                    Text(artist.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(Formatters.tracks(artist.tracks.count))
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                }
                .padding(.top, 12)

                PlayShuffleButtons {
                    AudioPlayerManager.shared.playInOrder(queue)
                } onShuffle: {
                    AudioPlayerManager.shared.playShuffled(queue)
                }
                .padding(.horizontal, Metrics.screenPadding)

                LazyVStack(spacing: 2) {
                    ForEach(Array(artist.tracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            AudioPlayerManager.shared.play(track: queue[index], in: queue)
                        } label: {
                            TrackRow(
                                artwork: track.artworkKey,
                                title: track.display.title,
                                subtitle: MusicLibrary.sourceLabel(for: track),
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
                        .contextMenu {
                            TrackMenuItems(track: queue[index])
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .appNavigationBar(title: artist.name)
    }
}
