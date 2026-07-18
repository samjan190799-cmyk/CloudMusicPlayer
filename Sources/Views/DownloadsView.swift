import SwiftUI

/// Вкладка для отображения скачанной музыки и активных загрузок в реальном времени с премиальным дизайном
struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    
    // Вычисление общего объема памяти, занятого загрузками
    var totalStorageSize: Int64 {
        downloadManager.localTracks.reduce(0) { $0 + $1.size }
    }
    
    // Фильтрация треков
    var filteredTracks: [LocalTrack] {
        if searchText.isEmpty {
            return downloadManager.localTracks
        } else {
            return downloadManager.localTracks.filter { track in
                track.title.localizedCaseInsensitiveContains(searchText) ||
                (track.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Премиальный фоновый градиент
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.16),
                        Color(red: 0.10, green: 0.04, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Информационный дашборд сверху
                    if !downloadManager.localTracks.isEmpty {
                        storageDashboard
                    }
                    
                    // Активные загрузки в реальном времени
                    let activeList = downloadManager.activeDownloadsList
                    if !activeList.isEmpty {
                        activeDownloadsSection(activeList: activeList)
                    }
                    
                    // Поисковая панель
                    searchBar
                    
                    // Список треков
                    if filteredTracks.isEmpty {
                        emptyStateView
                    } else {
                        tracksListView
                    }
                }
            }
            .navigationTitle("Загрузки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredTracks.isEmpty {
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            if let first = filteredTracks.first {
                                playLocalTrack(first)
                            }
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Панель статистики (Дашборд)
    
    private var storageDashboard: some View {
        HStack(spacing: 16) {
            // Карточка: Всего треков
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "music.note.list")
                        .foregroundColor(.purple)
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(downloadManager.localTracks.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("файлов")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            
            // Карточка: Занятая память
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "internaldrive")
                        .foregroundColor(.cyan)
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatSize(totalStorageSize))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("использовано")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    // MARK: - Секция активных загрузок
    
    private func activeDownloadsSection(activeList: [ActiveDownload]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Загружается сейчас")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                Spacer()
                Text("\(activeList.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(activeList) { download in
                        HStack(spacing: 12) {
                            // Цветная иконка источника
                            ZStack {
                                Circle()
                                    .fill(sourceColor(download.source).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: sourceIcon(download.source))
                                    .foregroundColor(sourceColor(download.source))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(download.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    ProgressView(value: download.progress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: sourceColor(download.source)))
                                        .frame(height: 4)
                                    
                                    Text("\(Int(download.progress * 100))%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray)
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.triggerImpact(style: .light)
                                downloadManager.cancelDownload(trackId: download.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.8))
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 180)
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.top, 6)
        }
    }
    
    // MARK: - Поисковая панель
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Поиск среди скачанных...", text: $searchText)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // MARK: - Пустое состояние
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(searchText.isEmpty ? "Нет скачанных файлов" : "Ничего не найдено")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ? "Скачивайте песни с YouTube или из облачных дисков во вкладках ниже для прослушивания офлайн." : "Попробуйте изменить поисковый запрос.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Spacer()
        }
    }
    
    // MARK: - Список файлов
    
    private var tracksListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredTracks) { localTrack in
                    trackRow(for: localTrack)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Карточка трека (Row)
    
    private func trackRow(for localTrack: LocalTrack) -> some View {
        let isPlayingThis = playerManager.currentTrack?.id == localTrack.id
        let fileExtension = URL(fileURLWithPath: localTrack.relativePath).pathExtension.uppercased()
        
        return HStack(spacing: 12) {
            // Кнопка воспроизведения (включает обложку)
            Button(action: {
                playLocalTrack(localTrack)
            }) {
                HStack(spacing: 12) {
                    // Обложка трека
                    ZStack(alignment: .bottomTrailing) {
                        if let coverURL = localTrack.localCoverURL,
                           let uiImage = UIImage(contentsOfFile: coverURL.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            // Современный градиентный плейсхолдер
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        // Анимированный мини-визуализатор
                        if isPlayingThis && playerManager.playbackState == .playing {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 52, height: 52)
                            
                            MiniVisualizerView(isPlaying: true)
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                    // Название и метаданные
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localTrack.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isPlayingThis ? .cyan : .white)
                            .lineLimit(1)
                        
                        Text(localTrack.artist ?? "Неизвестный исполнитель")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        // Строка детальной информации о файле
                        HStack(spacing: 6) {
                            // Формат файла (MP3 / M4A)
                            Text(fileExtension)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(4)
                            
                            Text("•")
                                .foregroundColor(.gray.opacity(0.5))
                                .font(.system(size: 10))
                            
                            // Размер файла
                            Text(formatSize(localTrack.size))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            
                            // Длительность
                            if let dur = localTrack.duration, dur > 0 {
                                Text("•")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .font(.system(size: 10))
                                
                                Text(formatDuration(dur))
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Компактный бейдж источника трека
            Text(sourceBadgeText(localTrack.source))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(sourceColor(localTrack.source))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(sourceColor(localTrack.source).opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(sourceColor(localTrack.source).opacity(0.2), lineWidth: 1)
                )
            
            // Кнопка контекстного меню
            Menu {
                Button(role: .destructive, action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    deleteTrack(localTrack)
                }) {
                    Label("Удалить из загрузок", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
            }
        }
        .padding(10)
        .background(isPlayingThis ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlayingThis ? Color.cyan.opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
    
    // MARK: - Вспомогательные методы
    
    private func playLocalTrack(_ track: LocalTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        
        let playerTrack = PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.artist ?? track.source.displayName,
            sourceName: "Загрузки",
            localURL: track.localURL,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: track.localCoverURL,
            duration: track.duration
        )
        
        let queue = downloadManager.localTracks.map { t in
            PlayerTrack(
                id: t.id,
                title: t.title,
                artist: t.artist ?? t.source.displayName,
                sourceName: "Загрузки",
                localURL: t.localURL,
                remoteURL: nil,
                googleFileId: nil,
                localCoverURL: t.localCoverURL,
                duration: t.duration
            )
        }
        playerManager.play(track: playerTrack, in: queue)
    }
    
    private func deleteTrack(_ track: LocalTrack) {
        downloadManager.deleteTrack(trackId: track.id)
        if playerManager.currentTrack?.id == track.id {
            playerManager.previousTrack()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // Цветовая палитра для источников
    private func sourceColor(_ source: TrackSource) -> Color {
        switch source {
        case .google: return .purple
        case .yandex: return .red
        case .youtube: return .orange
        }
    }
    
    private func sourceIcon(_ source: TrackSource) -> String {
        switch source {
        case .google: return "cloud.fill"
        case .yandex: return "icloud.fill"
        case .youtube: return "play.rectangle.fill"
        }
    }
    
    private func sourceBadgeText(_ source: TrackSource) -> String {
        switch source {
        case .google: return "DRIVE"
        case .yandex: return "YANDEX"
        case .youtube: return "YOUTUBE"
        }
    }
}

// MARK: - Локальный ScaleButtonStyle (без конфликтов)

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
