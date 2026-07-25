import SwiftUI

/// Источник облачных файлов
enum CloudSource {
    case google
    case yandex
    case telegram
}

/// Экран для работы с файлами на облачном диске
struct CloudView: View {
    let source: CloudSource
    
    @ObservedObject var googleService = GoogleDriveService.shared
    @ObservedObject var yandexService = YandexDiskService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    @State private var searchText = ""
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    @Binding var selectedTab: Int // Для переключения на вкладку настроек
    
    var title: String {
        switch source {
        case .google: return "Google Диск"
        case .yandex: return "Яндекс Диск"
        case .telegram: return "Telegram"
        }
    }
    
    var isAuthenticated: Bool {
        source == .google ? googleService.isAuthenticated : yandexService.isAuthenticated
    }
    
    var isLoading: Bool {
        source == .google ? googleService.isLoading : yandexService.isLoading
    }
    
    var errorMessage: String? {
        source == .google ? googleService.errorMessage : yandexService.errorMessage
    }
    
    // Списки файлов
    var googleTracks: [GoogleTrack] {
        if searchText.isEmpty {
            return googleService.tracks
        } else {
            return googleService.tracks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var yandexTracks: [YandexTrack] {
        if searchText.isEmpty {
            return yandexService.tracks
        } else {
            return yandexService.tracks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            mainContent
        }
        .sheet(item: $selectedTrackForPlaylist) { track in
            AddToPlaylistView(track: track)
        }
        .onAppear {
            if isAuthenticated {
                refreshFiles()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if source == .telegram {
            TelegramCloudView()
        } else if !isAuthenticated {
            unauthenticatedView
        } else {
            driveContentView
        }
    }

    // MARK: - Экран Неавторизованного Состояния (Unauthenticated View)

    private var unauthenticatedView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    source == .google ? Color.blue.opacity(0.4) : Color.red.opacity(0.4),
                                    AppTheme.neonPurple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .blur(radius: 12)

                    Image(systemName: source == .google ? "logo.googledrive" : "y.circle.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: source == .google ? [.blue, .cyan] : [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Подключите \(title)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Авторизуйтесь в настройках для прямого онлайн-прослушивания и скачивания ваших файлов.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Button(action: {
                    HapticManager.shared.triggerSelection()
                    withAnimation {
                        selectedTab = 4 // Переход на вкладку Настройки
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Перейти в настройки")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: source == .google ? [.blue, AppTheme.neonPurple] : [.red, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .neonGlow(color: source == .google ? .blue : .red, radius: 10, opacity: 0.5)
                }
                .buttonStyle(SpringScaleButtonStyle())
            }
            .padding(32)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.65)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Содержимое подключенного облака (Drive Content View)

    private var driveContentView: some View {
        VStack(spacing: 14) {
            // Поисковая строка в стиле Liquid Glass
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.neonCyan)

                TextField("Поиск треков на \(title)...", text: $searchText)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .medium))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                            .font(.system(size: 18))
                    }
                }
                
                Button(action: {
                    HapticManager.shared.triggerSelection()
                    refreshFiles()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 16, opacity: 0.45)
            .padding(.horizontal, 20)

            // Контентная зона
            if isLoading {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                        .scaleEffect(1.3)
                    Text("Загрузка содержимого \(title)...")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button("Повторить попытку") {
                        HapticManager.shared.triggerSelection()
                        refreshFiles()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                Spacer()
            } else if (source == .google ? googleTracks.isEmpty : yandexTracks.isEmpty) {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "cloud.slash.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("На \(title) не найдено аудиофайлов")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Загрузите файлы аудиоформатов (.mp3, .m4a, .flac) на ваш диск.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(28)
                .background(
                    ZStack {
                        VisualEffectBlur(material: .systemUltraThinMaterialDark)
                        Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.6)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if source == .google {
                            ForEach(googleTracks) { track in
                                CloudTrackRowView(
                                    id: track.id,
                                    title: track.name,
                                    formattedSize: formatSize(track.sizeInBytes),
                                    downloadStatus: downloadManager.getDownloadStatus(for: track.id),
                                    isPlaying: playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing,
                                    onPlay: {
                                        playOnlineTrack(id: track.id, title: track.name, sourceTrack: .google(track))
                                    },
                                    onDownload: {
                                        startDownload(.google(track))
                                    },
                                    onCancelDownload: {
                                        downloadManager.cancelDownload(trackId: track.id)
                                    },
                                    onAddToPlaylist: {
                                        selectedTrackForPlaylist = TrackEnum.google(track).toPlaylistTrack()
                                    }
                                )
                            }
                        } else {
                            ForEach(yandexTracks) { track in
                                CloudTrackRowView(
                                    id: track.id,
                                    title: track.name,
                                    formattedSize: formatSize(track.size ?? 0),
                                    downloadStatus: downloadManager.getDownloadStatus(for: track.id),
                                    isPlaying: playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing,
                                    onPlay: {
                                        playOnlineTrack(id: track.id, title: track.name, sourceTrack: .yandex(track))
                                    },
                                    onDownload: {
                                        startDownload(.yandex(track))
                                    },
                                    onCancelDownload: {
                                        downloadManager.cancelDownload(trackId: track.id)
                                    },
                                    onAddToPlaylist: {
                                        selectedTrackForPlaylist = TrackEnum.yandex(track).toPlaylistTrack()
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func refreshFiles() {
        if source == .google {
            googleService.fetchAudioFiles()
        } else {
            yandexService.fetchAudioFiles()
        }
    }

    private func startDownload(_ track: TrackEnum) {
        HapticManager.shared.triggerSelection()
        switch track {
        case .google(let googleTrack):
            downloadManager.downloadGoogleTrack(googleTrack)
        case .yandex(let yandexTrack):
            downloadManager.downloadYandexTrack(yandexTrack)
        }
    }

    /// Запуск онлайн стриминга
    private func playOnlineTrack(id: String, title: String, sourceTrack: TrackEnum) {
        HapticManager.shared.triggerSelection()
        var playerTrack: PlayerTrack

        switch sourceTrack {
        case .google(let track):
            playerTrack = PlayerTrack(
                id: track.id,
                title: track.name,
                artist: "Google Drive",
                sourceName: "Google Drive (Онлайн)",
                localURL: nil,
                remoteURL: nil,
                googleFileId: track.id
            )
        case .yandex(let track):
            playerTrack = PlayerTrack(
                id: track.id,
                title: track.name,
                artist: "Яндекс Диск",
                sourceName: "Яндекс Диск (Онлайн)",
                localURL: nil,
                remoteURL: nil,
                googleFileId: nil
            )
        }

        // Создаем очередь из текущего списка файлов на диске
        let queue: [PlayerTrack]
        if source == .google {
            queue = googleService.tracks.map { track in
                PlayerTrack(
                    id: track.id,
                    title: track.name,
                    artist: "Google Drive",
                    sourceName: "Google Drive (Онлайн)",
                    localURL: nil,
                    remoteURL: nil,
                    googleFileId: track.id
                )
            }
        } else {
            queue = yandexService.tracks.map { track in
                PlayerTrack(
                    id: track.id,
                    title: track.name,
                    artist: "Яндекс Диск",
                    sourceName: "Яндекс Диск (Онлайн)",
                    localURL: nil,
                    remoteURL: nil,
                    googleFileId: nil
                )
            }
        }

        playerManager.play(track: playerTrack, in: queue)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Вынесенный компонент карточки трека в облаке (для мгновенной компиляции Swift 6)

private struct CloudTrackRowView: View {
    let id: String
    let title: String
    let formattedSize: String
    let downloadStatus: DownloadStatus
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDownload: () -> Void
    let onCancelDownload: () -> Void
    let onAddToPlaylist: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                // Иконка Воспроизведения
                ZStack {
                    LinearGradient(
                        colors: [
                            isPlaying ? Color.cyan : Color(red: 0.2, green: 0.12, blue: 0.4),
                            Color(red: 0.1, green: 0.15, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 1)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Текстовая информация
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(formattedSize)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                // Меню опций
                Menu {
                    Button(action: onAddToPlaylist) {
                        Label("Добавить в плейлист", systemImage: "plus.circle")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 32, height: 32)
                }

                // Индикатор и кнопка скачивания
                downloadButtonSection
            }
            .padding(12)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.65)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isPlaying ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(SpringScaleButtonStyle())
    }

    @ViewBuilder
    private var downloadButtonSection: some View {
        switch downloadStatus {
        case .notDownloaded:
            Button(action: onDownload) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 34, height: 34)
                .neonGlow(color: .purple, radius: 4, opacity: 0.4)
            }
            .buttonStyle(SpringScaleButtonStyle())

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(Color.cyan, lineWidth: 2.5)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))

                Button(action: onCancelDownload) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

        case .downloaded:
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 34, height: 34)

        case .failed:
            Button(action: onDownload) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                }
                .frame(width: 34, height: 34)
            }
        }
    }
}

// MARK: - Перечисление для типизации трека
enum TrackEnum {
    case google(GoogleTrack)
    case yandex(YandexTrack)
}

extension TrackEnum {
    func toPlaylistTrack() -> PlaylistTrack {
        switch self {
        case .google(let track):
            return PlaylistTrack(
                id: track.id,
                title: track.name,
                artist: "Google Drive",
                sourceName: "Google Drive",
                localRelativePath: nil,
                remoteURLString: nil,
                googleFileId: track.id,
                duration: nil
            )
        case .yandex(let track):
            return PlaylistTrack(
                id: track.id,
                title: track.name,
                artist: "Яндекс Диск",
                sourceName: "Яндекс Диск",
                localRelativePath: nil,
                remoteURLString: nil,
                googleFileId: nil,
                duration: nil
            )
        }
    }
}
