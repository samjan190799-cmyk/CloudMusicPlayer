import SwiftUI

/// Вкладка Загрузок в едином премиальном стиле Liquid Glass 2026
struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    
    // Общий размер скачанных файлов
    var totalStorageSize: Int64 {
        downloadManager.localTracks.reduce(0) { $0 + $1.size }
    }
    
    // Фильтрованные треки
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
                // Глубокий неоново-фиолетовый космический градиент на фоне
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.18, blue: 0.45),
                        Color(red: 0.12, green: 0.08, blue: 0.28),
                        Color(red: 0.06, green: 0.04, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Мягкое нежное свечение на фоне
                GeometryReader { proxy in
                    Circle()
                        .fill(Color(red: 0.35, green: 0.25, blue: 0.95).opacity(0.25))
                        .blur(radius: 80)
                        .frame(width: proxy.size.width * 0.85)
                        .offset(x: proxy.size.width * 0.2, y: -40)
                }
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // 1. Хедер (Загрузки + Кнопка Воспроизвести Все)
                        headerView
                        
                        // 2. Панель Статистики Памяти (Storage Dashboard)
                        if !downloadManager.localTracks.isEmpty {
                            storageDashboard
                        }
                        
                        // 3. Секция Активных Загрузок в реальном времени
                        let activeList = downloadManager.activeDownloadsList
                        if !activeList.isEmpty {
                            activeDownloadsSection(activeList: activeList)
                        }
                        
                        // 4. Поисковая Панель
                        if !downloadManager.localTracks.isEmpty {
                            searchBar
                        }
                        
                        // 5. Список Файлов или Пустое Состояние
                        if filteredTracks.isEmpty {
                            emptyStateView
                        } else {
                            downloadedTracksSection
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Хедер (Загрузки + Кнопка Play)
    
    private var headerView: some View {
        HStack {
            Text("Загрузки")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            if !filteredTracks.isEmpty {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    if let first = filteredTracks.first {
                        playLocalTrack(first)
                    }
                }) {
                    ZStack {
                        VisualEffectBlur(material: .systemUltraThinMaterialDark)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.3, blue: 1.0), Color(red: 0.45, green: 0.2, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                            .offset(x: 1)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(SpringScaleButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Панель Статистики Памяти (Storage Dashboard)
    
    private var storageDashboard: some View {
        HStack(spacing: 14) {
            // Фактически треков
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 18, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(downloadManager.localTracks.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("файлов")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(14)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Занятая память
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatBytes(totalStorageSize))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("занято")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(14)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Активные Загрузки (Real-time Progress)
    
    private func activeDownloadsSection(activeList: [ActiveDownload]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Загружаются сейчас")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 24)
            
            VStack(spacing: 10) {
                ForEach(activeList, id: \.id) { download in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .trim(from: 0, to: download.progress)
                                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(download.progress * 100))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(download.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("Скачивание из облака...")
                                .font(.system(size: 12))
                                .foregroundColor(.cyan)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        ZStack {
                            VisualEffectBlur(material: .systemUltraThinMaterialDark)
                            Color(red: 0.15, green: 0.1, blue: 0.3).opacity(0.7)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Поисковая Панель
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 16, weight: .medium))
            
            TextField("Поиск среди скачанных файлов...", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 15))
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                VisualEffectBlur(material: .systemUltraThinMaterialDark)
                Color.white.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Список Загруженных Треков
    
    private var downloadedTracksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Скачанные файлы")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                ForEach(filteredTracks) { track in
                    downloadedTrackRowCard(track: track)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func downloadedTrackRowCard(track: LocalTrack) -> some View {
        let isPlaying = playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing
        return DownloadedTrackRowView(
            track: track,
            isPlaying: isPlaying,
            formattedSize: formatBytes(track.size),
            onPlay: {
                HapticManager.shared.triggerSelection()
                playLocalTrack(track)
            },
            onAddToPlaylist: {
                selectedTrackForPlaylist = PlaylistTrack(
                    id: track.id,
                    title: track.title,
                    artist: track.artist ?? "Скачанный трек",
                    sourceName: "Загрузки",
                    localRelativePath: track.relativePath,
                    remoteURLString: nil,
                    googleFileId: nil
                )
            },
            onDelete: {
                withAnimation {
                    downloadManager.deleteTrack(track)
                }
            }
        )
    }
    
    // MARK: - Пустое Состояние (Empty State)
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Нет скачанной музыки")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Перейдите в раздел «Облако» или «YouTube», чтобы скачать ваши аудиофайлы для оффлайн-прослушивания.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
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
    }
    
    // MARK: - Вспомогательные методы
    
    private func playLocalTrack(_ track: LocalTrack) {
        let allPlayerTracks = filteredTracks.map {
            PlayerTrack(
                id: $0.id,
                title: $0.title,
                artist: $0.artist ?? "Скачанный трек",
                sourceName: "Загрузки",
                localURL: $0.localURL,
                remoteURL: nil,
                googleFileId: nil
            )
        }
        if let target = allPlayerTracks.first(where: { $0.id == track.id }) {
            playerManager.play(track: target, in: allPlayerTracks)
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Отдельный компонент строки скачанного трека (для мгновенной компиляции Swift)

private struct DownloadedTrackRowView: View {
    let track: LocalTrack
    let isPlaying: Bool
    let formattedSize: String
    let onPlay: () -> Void
    let onAddToPlaylist: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                ZStack {
                    LinearGradient(
                        colors: [
                            isPlaying ? Color.cyan : Color(red: 0.25, green: 0.12, blue: 0.45),
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
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(track.artist ?? "Скачанный файл")
                            .lineLimit(1)
                        Text("•")
                        Text(formattedSize)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Меню действий (Добавить в плейлист / Удалить)
                Menu {
                    Button(action: onAddToPlaylist) {
                        Label("Добавить в плейлист", systemImage: "plus.circle")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить файл", systemImage: "trash")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 34, height: 34)
                }
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
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(SpringScaleButtonStyle())
    }
}
