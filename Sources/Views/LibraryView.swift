import SwiftUI

/// Главный экран (Медиатека) в стиле премиального Liquid Glass без демо-данных
struct LibraryView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var deviceScanner = DeviceMediaScanner.shared
    
    @State private var searchText = ""
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    @State private var showingCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var showDocumentPicker = false
    
    var filteredLocalTracks: [LocalTrack] {
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
                
                // Мягкое анимированное нежное свечение на фоне
                GeometryReader { proxy in
                    Circle()
                        .fill(Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.28))
                        .blur(radius: 80)
                        .frame(width: proxy.size.width * 0.9)
                        .offset(x: -40, y: -60)
                }
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // 1. Хедер (Главная + Создать плейлист)
                        headerView
                        
                        // 2. Секция Плейлистов (Реальные данные)
                        playlistsSection
                        
                        // 3. Секция Локальных треков (Реальные данные)
                        localTracksSection
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
            .sheet(isPresented: $showingCreatePlaylistAlert) {
                CreatePlaylistDialog(isPresented: $showingCreatePlaylistAlert, playlistName: $newPlaylistName) {
                    playlistManager.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                AudioDocumentPicker { urls in
                    deviceScanner.importFiles(from: urls)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Хедер (Главная + Действия)
    
    private var headerView: some View {
        HStack {
            Text("Главная")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Кнопка создания плейлиста
            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                showingCreatePlaylistAlert = true
            }) {
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Circle()
                        .fill(Color.white.opacity(0.12))
                    
                    Image(systemName: "plus")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(SpringScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Секция Плейлистов (Реальные данные)
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Плейлисты")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Spacer()
                
                if !playlistManager.playlists.isEmpty {
                    Text("\(playlistManager.playlists.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            
            if playlistManager.playlists.isEmpty {
                emptyPlaylistsCard
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(playlistManager.playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                realPlaylistCard(playlist: playlist)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    private var emptyPlaylistsCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Нет плейлистов")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Нажмите +, чтобы создать первый плейлист")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button("Создать") {
                showingCreatePlaylistAlert = true
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.cyan)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(16)
        .background(
            ZStack {
                VisualEffectBlur(material: .systemUltraThinMaterialDark)
                Color(red: 0.12, green: 0.1, blue: 0.24).opacity(0.6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func realPlaylistCard(playlist: Playlist) -> some View {
        ZStack(alignment: .bottom) {
            // Градиентный фон карточки
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.1, blue: 0.5),
                        Color(red: 0.08, green: 0.2, blue: 0.55),
                        Color(red: 0.05, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image(systemName: "music.quaver.at.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.15))
            }
            .frame(width: 210, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            
            // Нижняя плавающая матовая стеклянная плашка
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(playlist.tracks.count) треков")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.65, green: 0.3, blue: 1.0), Color(red: 0.45, green: 0.2, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
                .frame(width: 36, height: 36)
            }
            .padding(14)
            .frame(width: 210)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.12, blue: 0.28).opacity(0.7)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .frame(width: 210, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 7)
    }
    
    // MARK: - Секция Скачанных Треков (Реальные данные)
    
    private var localTracksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Медиатека")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Spacer()
                
                if !filteredLocalTracks.isEmpty {
                    Text("\(filteredLocalTracks.count) треков")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            
            if filteredLocalTracks.isEmpty {
                emptyTracksCard
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredLocalTracks) { track in
                        realTrackRowCard(track: track)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var emptyTracksCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Ваша медиатека пуста")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Загружайте музыку из облака (Google Drive, Яндекс Диск, Telegram) или импортируйте из YouTube.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(28)
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
    }
    
    private func realTrackRowCard(track: LocalTrack) -> some View {
        let isPlaying = playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing
        return LocalTrackRowView(
            track: track,
            isPlaying: isPlaying,
            onPlay: {
                HapticManager.shared.triggerSelection()
                playTrack(track)
            },
            onAddToPlaylist: {
                HapticManager.shared.triggerSelection()
                selectedTrackForPlaylist = PlaylistTrack(
                    id: track.id,
                    title: track.title,
                    artist: track.artist ?? "Неизвестный исполнитель",
                    localPath: track.localURL.path
                )
            }
        )
    }
    
    private func playTrack(_ track: LocalTrack) {
        let playerTrack = PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.artist ?? "Неизвестный исполнитель",
            sourceName: "Медиатека",
            localURL: track.localURL,
            remoteURL: nil,
            googleFileId: nil
        )
        let allPlayerTracks = filteredLocalTracks.map {
            PlayerTrack(
                id: $0.id,
                title: $0.title,
                artist: $0.artist ?? "Неизвестный исполнитель",
                sourceName: "Медиатека",
                localURL: $0.localURL,
                remoteURL: nil,
                googleFileId: nil
            )
        }
        playerManager.play(track: playerTrack, in: allPlayerTracks)
    }
}

// MARK: - Отдельный компонент строки трека (для мгновенной компиляции Swift)

private struct LocalTrackRowView: View {
    let track: LocalTrack
    let isPlaying: Bool
    let onPlay: () -> Void
    let onAddToPlaylist: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                ZStack {
                    LinearGradient(
                        colors: [
                            isPlaying ? Color.cyan : Color(red: 0.2, green: 0.1, blue: 0.4),
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
                    
                    Text(track.artist ?? "Неизвестный исполнитель")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onAddToPlaylist) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(SpringScaleButtonStyle())
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