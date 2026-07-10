import SwiftUI

/// Источник облачных файлов
enum CloudSource {
    case google
    case yandex
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
        source == .google ? "Google Диск" : "Яндекс Диск"
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
        NavigationView {
            ZStack {
                // Фон
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    if !isAuthenticated {
                        // Заглушка неавторизованного состояния
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: source == .google ? "logo.googledrive" : "y.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.purple.opacity(0.8))
                            
                            Text("Подключите \(title)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Авторизуйтесь в настройках, чтобы получить доступ к аудиофайлам на вашем \(title) и слушать их онлайн.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                withAnimation {
                                    selectedTab = 4 // Настройки (пятый таб)
                                }
                            }) {
                                Text("Перейти в настройки")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .cornerRadius(12)
                                    .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(20)
                        Spacer()
                    } else {
                        // Поиск
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Поиск музыки на диске...", text: $searchText)
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        if isLoading {
                            Spacer()
                            ProgressView("Загрузка списка файлов...")
                                .foregroundColor(.white)
                            Spacer()
                        } else if let error = errorMessage {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                Button("Повторить попытку") {
                                    refreshFiles()
                                }
                                .foregroundColor(.cyan)
                            }
                            Spacer()
                        } else if (source == .google ? googleTracks.isEmpty : yandexTracks.isEmpty) {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("На диске нет аудиофайлов")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                Text("Загрузите файлы форматов .mp3 или других аудио на ваш диск.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            Spacer()
                        } else {
                            // Список треков
                            List {
                                if source == .google {
                                    ForEach(googleTracks) { track in
                                        trackRow(id: track.id, title: track.name, size: track.sizeInBytes, sourceTrack: .google(track))
                                    }
                                } else {
                                    ForEach(yandexTracks) { track in
                                        trackRow(id: track.id, title: track.name, size: track.size ?? 0, sourceTrack: .yandex(track))
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            .background(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isAuthenticated && !isLoading {
                        Button(action: {
                            refreshFiles()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .onAppear {
                if isAuthenticated {
                    refreshFiles()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedTrackForPlaylist) { track in
            AddToPlaylistView(track: track)
        }
    }
    
    /// Ряд трека
    private func trackRow(id: String, title: String, size: Int64, sourceTrack: TrackEnum) -> some View {
        let downloadStatus = downloadManager.getDownloadStatus(for: id)
        let isPlaying = playerManager.currentTrack?.id == id
        
        return HStack(spacing: 12) {
            // Кнопка проигрывания
            Button(action: {
                playOnlineTrack(id: id, title: title, sourceTrack: sourceTrack)
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                            .foregroundColor(isPlaying ? .cyan : .white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isPlaying ? .cyan : .white)
                            .lineLimit(1)
                        
                        Text(formatSize(size))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Кнопка контекстного меню плейлиста
            Menu {
                Button(action: {
                    selectedTrackForPlaylist = sourceTrack.toPlaylistTrack()
                }) {
                    Label("Добавить в плейлист", systemImage: "music.note.list")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            
            // Кнопка/индикатор скачивания
            ZStack {
                switch downloadStatus {
                case .notDownloaded:
                    Button(action: {
                        startDownload(sourceTrack)
                    }) {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(.purple)
                            .font(.system(size: 16))
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .clipShape(Circle())
                    }
                case .downloading(let progress):
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progress))
                            .stroke(Color.cyan, lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                        
                        Button(action: {
                            downloadManager.cancelDownload(trackId: id)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                case .downloaded:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18))
                        .padding(8)
                case .failed(let err):
                    Button(action: {
                        startDownload(sourceTrack)
                    }) {
                        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.04))
        .listRowSeparator(.hidden)
    }
    
    private func refreshFiles() {
        if source == .google {
            googleService.fetchAudioFiles()
        } else {
            yandexService.fetchAudioFiles()
        }
    }
    
    private func startDownload(_ track: TrackEnum) {
        switch track {
        case .google(let googleTrack):
            downloadManager.downloadGoogleTrack(googleTrack)
        case .yandex(let yandexTrack):
            downloadManager.downloadYandexTrack(yandexTrack)
        }
    }
    
    /// Запуск онлайн стриминга
    private func playOnlineTrack(id: String, title: String, sourceTrack: TrackEnum) {
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

/// Перечисление для типизации трека
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
                googleFileId: track.id
            )
        case .yandex(let track):
            return PlaylistTrack(
                id: track.id,
                title: track.name,
                artist: "Яндекс Диск",
                sourceName: "Яндекс Диск",
                localRelativePath: nil,
                remoteURLString: nil,
                googleFileId: nil
            )
        }
    }
}
