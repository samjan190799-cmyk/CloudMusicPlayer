import SwiftUI

/// Музыка из Google Диска или Яндекс Диска: подключение, поиск, онлайн-прослушивание и загрузка
struct CloudDriveView: View {
    let provider: CloudProvider

    @ObservedObject private var google = GoogleDriveService.shared
    @ObservedObject private var yandex = YandexDiskService.shared
    @ObservedObject private var status = PlaybackStatus.shared

    @State private var searchText = ""
    @State private var showDisconnect = false

    private var isConnected: Bool {
        provider == .google ? google.isAuthenticated : yandex.isAuthenticated
    }

    private var isLoading: Bool {
        provider == .google ? google.isLoading : yandex.isLoading
    }

    private var errorMessage: String? {
        provider == .google ? google.errorMessage : yandex.errorMessage
    }

    /// Все треки диска в виде треков плеера
    private var tracks: [PlayerTrack] {
        if provider == .google {
            return google.tracks.map { CloudTracks.playerTrack($0) }
        }
        return yandex.tracks.map { CloudTracks.playerTrack($0) }
    }

    private func sizeText(for id: String) -> String? {
        if provider == .google {
            guard let size = google.tracks.first(where: { $0.id == id })?.sizeInBytes, size > 0 else { return nil }
            return Formatters.bytes(size)
        }
        guard let size = yandex.tracks.first(where: { $0.id == id })?.size, size > 0 else { return nil }
        return Formatters.bytes(size)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isConnected {
                    connectedContent
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Подключите \(provider.title), чтобы слушать свою музыку онлайн и скачивать её в медиатеку.")
                            .font(.appBody)
                            .foregroundColor(Palette.textSecondary)
                        if provider == .google {
                            GoogleConnectForm()
                        } else {
                            YandexConnectForm()
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            refresh()
        }
        .background(AppBackground(glow: provider == .google ? Color(red: 0.26, green: 0.52, blue: 0.96) : Color(red: 1.0, green: 0.7, blue: 0.1)))
        .appNavigationBar(title: provider.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isConnected {
                    Menu {
                        Button {
                            refresh()
                        } label: {
                            Label("Обновить", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            showDisconnect = true
                        } label: {
                            Label("Отключить", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .confirmationDialog("Отключить \(provider.title)?", isPresented: $showDisconnect, titleVisibility: .visible) {
            Button("Отключить", role: .destructive) {
                if provider == .google {
                    google.logout()
                } else {
                    yandex.logout()
                }
            }
        } message: {
            Text("Скачанные треки останутся на устройстве.")
        }
        .onAppear {
            if isConnected && tracks.isEmpty && !isLoading {
                refresh()
            }
        }
    }

    private func refresh() {
        if provider == .google {
            google.fetchAudioFiles()
        } else {
            yandex.fetchAudioFiles()
        }
    }

    // MARK: - Контент подключённого диска

    @ViewBuilder
    private var connectedContent: some View {
        let all = tracks
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let visible = query.isEmpty ? all : all.filter {
            $0.display.title.localizedCaseInsensitiveContains(query)
                || $0.display.artist.localizedCaseInsensitiveContains(query)
        }

        SearchField(text: $searchText, placeholder: "Поиск на \(provider.title)")
            .padding(.horizontal, Metrics.screenPadding)

        if isLoading && all.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 60)
                Spacer()
            }
        } else if let error = errorMessage, all.isEmpty {
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
                title: "Не удалось загрузить",
                message: error,
                actionTitle: "Повторить"
            ) {
                refresh()
            }
        } else if all.isEmpty {
            EmptyStateView(
                icon: "cloud",
                title: "Аудиофайлов не найдено",
                message: "Загрузите на диск файлы MP3, M4A или FLAC и потяните экран вниз, чтобы обновить."
            )
        } else {
            if query.isEmpty {
                PlayShuffleButtons {
                    AudioPlayerManager.shared.playInOrder(all)
                } onShuffle: {
                    AudioPlayerManager.shared.playShuffled(all)
                }
                .padding(.horizontal, Metrics.screenPadding)
            }

            Text(Formatters.tracks(visible.count))
                .font(.appCaption)
                .foregroundColor(Palette.textTertiary)
                .padding(.horizontal, Metrics.screenPadding)

            LazyVStack(spacing: 2) {
                ForEach(visible, id: \.id) { track in
                    row(track, queue: visible)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private func row(_ track: PlayerTrack, queue: [PlayerTrack]) -> some View {
        let display = track.display
        let size = sizeText(for: track.id)
        let subtitle = size.map { "\(display.artist) · \($0)" } ?? display.artist

        return Button {
            HapticManager.shared.triggerImpact(style: .medium)
            AudioPlayerManager.shared.play(track: track, in: queue)
        } label: {
            TrackRow(
                artwork: track.artworkKey,
                title: display.title,
                subtitle: subtitle,
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id)
            ) {
                HStack(spacing: 0) {
                    LiveDownloadButton(trackID: track.id) {
                        _ = TrackActions.download(track)
                    }
                    Menu {
                        TrackMenuItems(track: track)
                    } label: {
                        MoreMenuLabel()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            TrackMenuItems(
                track: track,
                onDownload: TrackActions.canDownload(track) ? { _ = TrackActions.download(track) } : nil
            )
        }
    }
}
