import SwiftUI

/// Вкладка оффлайн-медиатеки с премиальным стеклянным дизайном (Glassmorphism)
struct LibraryView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    @State private var searchText = ""
    @State private var selectedSection = 0 // 0 - Треки, 1 - Плейлисты, 2 - Избранное
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    @State private var showingCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    
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
    
    var favoritesTracks: [PlaylistTrack] {
        let allFavorites = playlistManager.playlists.first(where: { $0.id == PlaylistManager.favoritesUUID })?.tracks ?? []
        if searchText.isEmpty {
            return allFavorites
        } else {
            return allFavorites.filter { track in
                track.title.localizedCaseInsensitiveContains(searchText) ||
                track.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Премиальный фоновый градиент (глубокий фиолетовый космос)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.16),
                        Color(red: 0.12, green: 0.04, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Кастомный Хедер (Today / Медиатека)
                    headerView
                    
                    // Кастомный переключатель разделов (капсула в стиле Glassmorphism)
                    customSectionPicker
                    
                    // Содержимое выбранного раздела
                    ScrollView {
                        VStack(spacing: 20) {
                            if selectedSection == 0 {
                                // Раздел "Треки"
                                tracksSection
                            } else if selectedSection == 1 {
                                // Раздел "Плейлисты"
                                playlistsSection
                            } else {
                                // Раздел "Избранное"
                                favoritesSection
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true) // Скрываем стандартный навигейшн бар ради кастомного
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
            .sheet(isPresented: $showingCreatePlaylistAlert) {
                CreatePlaylistDialog(isPresented: $showingCreatePlaylistAlert, playlistName: $newPlaylistName) {
                    playlistManager.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Кастомный Хедер
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection == 0 ? "Today" : (selectedSection == 1 ? "Playlists" : "Favorites"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                
                Text(selectedSection == 0 ? "Ваша медиатека" : (selectedSection == 1 ? "Ваши подборки" : "Любимая музыка"))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Круглая стеклянная кнопка действия справа
            if selectedSection == 1 {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    showingCreatePlaylistAlert = true
                }) {
                    ZStack {
                        VisualEffectBlur(material: .systemUltraThinMaterial)
                        Circle()
                            .fill(Color.white.opacity(0.06))
                        
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                // Плейсхолдер профиля в стеклянном стиле как на дизайне
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterial)
                    Circle()
                        .fill(Color.white.opacity(0.06))
                    
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 16))
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
    
    // MARK: - Кастомный переключатель разделов
    
    private var customSectionPicker: some View {
        HStack(spacing: 0) {
            sectionPickerButton(title: "Треки", index: 0)
            sectionPickerButton(title: "Плейлисты", index: 1)
            sectionPickerButton(title: "Избранное", index: 2)
        }
        .padding(4)
        .background(
            ZStack {
                VisualEffectBlur(material: .systemUltraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private func sectionPickerButton(title: String, index: Int) -> some View {
        let isSelected = selectedSection == index
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedSection = index
                HapticManager.shared.triggerSelection()
            }
        }) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Секция треков (Раздел 0)
    
    private var tracksSection: some View {
        VStack(spacing: 16) {
            searchBar
            
            if filteredTracks.isEmpty {
                emptyState(
                    icon: "folder.badge.minus",
                    title: "Медиатека пуста",
                    text: "Скачивайте файлы из Google Диска или Яндекс Диска во вкладках ниже для прослушивания офлайн."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredTracks) { localTrack in
                        trackRow(for: localTrack)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Секция плейлистов (Раздел 1)
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if playlistManager.playlists.isEmpty {
                emptyState(
                    icon: "music.note.list",
                    title: "У вас нет плейлистов",
                    text: "Создайте новый плейлист с помощью кнопки + в верхнем углу."
                )
            } else {
                // 1. Горизонтальная карусель плейлистов (как в дизайне)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Коллекции")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(playlistManager.playlists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    playlistHorizontalCard(playlist: playlist)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // 2. Список всех офлайн треков под каруселью плейлистов
                VStack(alignment: .leading, spacing: 12) {
                    Text("Все треки")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    if downloadManager.localTracks.isEmpty {
                        Text("Нет треков")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(downloadManager.localTracks.prefix(8)) { track in
                                trackRow(for: track)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Секция избранного (Раздел 2)
    
    private var favoritesSection: some View {
        VStack(spacing: 16) {
            searchBar
            
            if favoritesTracks.isEmpty {
                emptyState(
                    icon: "heart.slash",
                    title: "Нет избранных треков",
                    text: "Добавляйте треки в избранное с помощью кнопки сердечка в плеере."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(favoritesTracks) { playlistTrack in
                        favoriteTrackRow(for: playlistTrack)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Поисковая панель
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Поиск...", text: $searchText)
                .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Карточка плейлиста в горизонтальной карусели
    
    private func playlistHorizontalCard(playlist: Playlist) -> some View {
        let isFavorites = playlist.id == PlaylistManager.favoritesUUID
        
        return VStack(alignment: .leading, spacing: 10) {
            // Картинка-обложка плейлиста
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isFavorites ? [.pink, .purple] : [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 170, height: 130)
                
                Image(systemName: isFavorites ? "heart.fill" : "music.note.list")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 170, height: 130, alignment: .center)
                
                // Кнопка быстрого проигрывания (как на макете)
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    if let first = playlist.tracks.first {
                        let playerTrack = first.toPlayerTrack()
                        let queue = playlist.tracks.map { $0.toPlayerTrack() }
                        playerManager.play(track: playerTrack, in: queue)
                    }
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                                .offset(x: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(10)
            }
            
            // Название плейлиста
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(playlist.tracks.count) треков")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 170)
        .contextMenu {
            if !isFavorites {
                Button(role: .destructive, action: {
                    playlistManager.deletePlaylist(id: playlist.id)
                }) {
                    Label("Удалить плейлист", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Ряд офлайн трека (Row)
    
    private func trackRow(for localTrack: LocalTrack) -> some View {
        let isPlayingThis = playerManager.currentTrack?.id == localTrack.id
        
        return HStack(spacing: 12) {
            // Кнопка Play прямо поверх обложки трека (как на дизайне)
            Button(action: {
                playLocalTrack(localTrack)
            }) {
                ZStack {
                    if let coverURL = localTrack.localCoverURL,
                       let uiImage = UIImage(contentsOfFile: coverURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(placeholderGradient(for: localTrack.title))
                            .frame(width: 48, height: 48)
                            .opacity(0.8)
                    }
                    
                    // Кнопка воспроизведения поверх обложки
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: isPlayingThis && playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: isPlayingThis && playerManager.playbackState == .playing ? 0 : 0.5)
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Инфо
            VStack(alignment: .leading, spacing: 4) {
                Text(localTrack.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isPlayingThis ? .cyan : .white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(localTrack.artist ?? localTrack.source.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.purple.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(formatSize(localTrack.size))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Кнопка контекстного меню
            Menu {
                Button(action: {
                    selectedTrackForPlaylist = localTrack.toPlaylistTrack()
                }) {
                    Label("Добавить в плейлист", systemImage: "music.note.list")
                }
                
                Button(role: .destructive, action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    deleteTrack(localTrack)
                }) {
                    Label("Удалить из медиатеки", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }
            
            // Зелёная галочка офлайн скачивания
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.cyan)
                .font(.system(size: 12))
        }
        .padding(10)
        .background(isPlayingThis ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlayingThis ? Color.cyan.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
    
    // MARK: - Ряд избранного трека (Row)
    
    private func favoriteTrackRow(for playlistTrack: PlaylistTrack) -> some View {
        let isPlayingThis = playerManager.currentTrack?.id == playlistTrack.id
        
        return HStack(spacing: 12) {
            Button(action: {
                playFavoriteTrack(playlistTrack)
            }) {
                ZStack {
                    if let coverURL = playlistTrack.localCoverURL,
                       let uiImage = UIImage(contentsOfFile: coverURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(placeholderGradient(for: playlistTrack.title))
                            .frame(width: 48, height: 48)
                            .opacity(0.8)
                    }
                    
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: isPlayingThis && playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: isPlayingThis && playerManager.playbackState == .playing ? 0 : 0.5)
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlistTrack.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isPlayingThis ? .cyan : .white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(playlistTrack.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.purple.opacity(0.8))
                        .lineLimit(1)
                    
                    Text(playlistTrack.sourceName)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: {
                    playlistManager.removeTrack(trackId: playlistTrack.id, from: PlaylistManager.favoritesUUID)
                }) {
                    Label("Удалить из избранного", systemImage: "heart.slash.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
            }
        }
        .padding(10)
        .background(isPlayingThis ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlayingThis ? Color.cyan.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
    
    // MARK: - Заглушка ошибок / пустоты
    
    private func emptyState(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    
    private func playLocalTrack(_ localTrack: LocalTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        
        let playerTrack = PlayerTrack(
            id: localTrack.id,
            title: localTrack.title,
            artist: localTrack.artist ?? localTrack.source.displayName,
            sourceName: "Офлайн Медиатека",
            localURL: localTrack.localURL,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: localTrack.localCoverURL,
            duration: localTrack.duration
        )
        
        let queue = downloadManager.localTracks.map { track in
            PlayerTrack(
                id: track.id,
                title: track.title,
                artist: track.artist ?? track.source.displayName,
                sourceName: "Офлайн Медиатека",
                localURL: track.localURL,
                remoteURL: nil,
                googleFileId: nil,
                localCoverURL: track.localCoverURL,
                duration: track.duration
            )
        }
        playerManager.play(track: playerTrack, in: queue)
    }
    
    private func playFavoriteTrack(_ favoriteTrack: PlaylistTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        
        let playerTrack = favoriteTrack.toPlayerTrack()
        let favorites = playlistManager.playlists.first(where: { $0.id == PlaylistManager.favoritesUUID })
        let queue = (favorites?.tracks ?? []).map { $0.toPlayerTrack() }
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
    
    private func placeholderGradient(for title: String) -> LinearGradient {
        let colors: [[Color]] = [
            [.blue, .purple],
            [.purple, .pink],
            [.pink, .orange],
            [.orange, .yellow],
            [.teal, .blue],
            [.green, .teal]
        ]
        let index = abs(title.hashValue) % colors.count
        return LinearGradient(
            colors: colors[index],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Вспомогательный ScaleButtonStyle (локально)

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}