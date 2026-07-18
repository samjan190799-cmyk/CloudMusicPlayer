import SwiftUI

/// Вкладка оффлайн-медиатеки
struct LibraryView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    @State private var searchText = ""
    @State private var selectedSection = 0 // 0 - Треки, 1 - Плейлисты
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    @State private var showingCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    
    @AppStorage("isPlaylistGridView") private var isGridView = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var filteredTracks: [LocalTrack] {
        if searchText.isEmpty {
            return downloadManager.localTracks
        } else {
            return downloadManager.localTracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент темы
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    // Переключатель разделов
                    Picker("Раздел", selection: $selectedSection) {
                        Text("Треки").tag(0)
                        Text("Плейлисты").tag(1)
                        Text("Избранное").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .onChange(of: selectedSection) { _ in
                        HapticManager.shared.triggerSelection()
                    }
                    
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
            }
            .navigationTitle(selectedSection == 0 ? "Моя Медиатека" : (selectedSection == 1 ? "Мои Плейлисты" : "Избранные песни"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSection == 0 {
                        if !downloadManager.localTracks.isEmpty {
                            Button(action: {
                                // Быстрое воспроизведение всей медиатеки
                                if let first = downloadManager.localTracks.first {
                                    playLocalTrack(first)
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                            }
                        }
                    } else if selectedSection == 1 {
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isGridView.toggle()
                                }
                            }) {
                                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2.fill")
                                    .font(.title3)
                                    .foregroundColor(.cyan)
                            }
                            
                            Button(action: {
                                showingCreatePlaylistAlert = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.cyan)
                            }
                        }
                    } else {
                        // Избранное
                        if !favoritesTracks.isEmpty {
                            Button(action: {
                                if let first = favoritesTracks.first {
                                    playFavoriteTrack(first)
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.pink)
                            }
                        }
                    }
                }
            }
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
    
    // Секция треков
    private var tracksSection: some View {
        VStack {
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Поиск в медиатеке...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            if filteredTracks.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text(searchText.isEmpty ? "Медиатека пуста" : "Ничего не найдено")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(searchText.isEmpty ? "Скачайте файлы из Google Диска или Яндекс Диска во вкладках ниже для прослушивания офлайн." : "Попробуйте изменить поисковый запрос.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                // Список треков
                List {
                    ForEach(filteredTracks) { localTrack in
                        let isPlayingThis = playerManager.currentTrack?.id == localTrack.id
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                playLocalTrack(localTrack)
                            }) {
                                HStack(spacing: 12) {
                                     // Иконка / Обложка
                                     ZStack(alignment: .bottomTrailing) {
                                         if let coverURL = localTrack.localCoverURL,
                                            let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                             Image(uiImage: uiImage)
                                                 .resizable()
                                                 .scaledToFill()
                                                 .frame(width: 44, height: 44)
                                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                             
                                             if isPlayingThis && playerManager.playbackState == .playing {
                                                 ZStack {
                                                     RoundedRectangle(cornerRadius: 3)
                                                         .fill(Color.black.opacity(0.6))
                                                         .frame(width: 18, height: 16)
                                                     
                                                     MiniVisualizerView(isPlaying: true)
                                                 }
                                                 .padding(2)
                                             }
                                         } else {
                                             RoundedRectangle(cornerRadius: 8)
                                                 .fill(placeholderGradient(for: localTrack.title))
                                                 .frame(width: 44, height: 44)
                                                 .opacity(0.85)
                                             
                                             if isPlayingThis && playerManager.playbackState == .playing {
                                                 MiniVisualizerView(isPlaying: true, tintColor: .white)
                                             } else {
                                                 Image(systemName: "music.note")
                                                     .foregroundColor(.white)
                                                     .font(.system(size: 14))
                                             }
                                         }
                                     }
                                    
                                    // Название трека и размер
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localTrack.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isPlayingThis ? .cyan : .white)
                                            .lineLimit(1)
                                            
                                            HStack(spacing: 8) {
                                                Text(localTrack.artist ?? localTrack.source.displayName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.purple.opacity(0.8))
                                                    .lineLimit(1)
                                                
                                                Text(formatSize(localTrack.size))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                            }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Кнопка контекстного меню
                            Menu {
                                Button(action: {
                                    selectedTrackForPlaylist = localTrack.toPlaylistTrack()
                                }) {
                                    Label("Добавить в плейлист", systemImage: "music.note.list")
                                }
                                
                                Button(role: .destructive, action: {
                                    deleteTrack(localTrack)
                                }) {
                                    Label("Удалить из медиатеки", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            
                            // Иконка оффлайн
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.cyan)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTrack(localTrack)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .padding(.top, 8)
            }
        }
    }
    
    // Секция плейлистов
    private var playlistsSection: some View {
        VStack {
            if playlistManager.playlists.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("У вас нет плейлистов")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Создайте новый плейлист с помощью кнопки + в верхнем углу.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                if isGridView {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(playlistManager.playlists) { playlist in
                                PlaylistGridCard(playlist: playlist)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 80) // Отступ для мини-плеера внизу
                    }
                } else {
                    List {
                        ForEach(playlistManager.playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(LinearGradient(
                                                colors: playlist.id == PlaylistManager.favoritesUUID ? [.pink, .purple] : [.purple, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 48, height: 48)
                                            .opacity(0.7)
                                        
                                        Image(systemName: playlist.id == PlaylistManager.favoritesUUID ? "heart.fill" : "music.note.list")
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text("\(playlist.tracks.count) треков")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if playlist.id != PlaylistManager.favoritesUUID {
                                    Button(role: .destructive) {
                                        playlistManager.deletePlaylist(id: playlist.id)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private func playLocalTrack(_ localTrack: LocalTrack) {
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
    
    // Список отфильтрованных избранных треков
    var favoritesTracks: [PlaylistTrack] {
        let allFavorites = playlistManager.playlists.first(where: { $0.id == PlaylistManager.favoritesUUID })?.tracks ?? []
        if searchText.isEmpty {
            return allFavorites
        } else {
            return allFavorites.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Секция избранного
    private var favoritesSection: some View {
        VStack {
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Поиск в избранном...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            if favoritesTracks.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 64))
                        .foregroundColor(.pink.opacity(0.6))
                    
                    Text(searchText.isEmpty ? "Нет избранных треков" : "Ничего не найдено")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(searchText.isEmpty ? "Добавляйте треки в избранное с помощью кнопки сердечка в плеере." : "Попробуйте изменить поисковый запрос.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(favoritesTracks) { playlistTrack in
                        let isPlayingThis = playerManager.currentTrack?.id == playlistTrack.id
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                playFavoriteTrack(playlistTrack)
                            }) {
                                HStack(spacing: 12) {
                                     // Иконка / Обложка
                                     ZStack(alignment: .bottomTrailing) {
                                         if let coverURL = playlistTrack.localCoverURL,
                                            let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                             Image(uiImage: uiImage)
                                                 .resizable()
                                                 .scaledToFill()
                                                 .frame(width: 44, height: 44)
                                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                             
                                             if isPlayingThis && playerManager.playbackState == .playing {
                                                 ZStack {
                                                     RoundedRectangle(cornerRadius: 3)
                                                         .fill(Color.black.opacity(0.6))
                                                         .frame(width: 18, height: 16)
                                                     
                                                     MiniVisualizerView(isPlaying: true)
                                                 }
                                                 .padding(2)
                                             }
                                         } else {
                                             RoundedRectangle(cornerRadius: 8)
                                                 .fill(placeholderGradient(for: playlistTrack.title))
                                                 .frame(width: 44, height: 44)
                                                 .opacity(0.85)
                                             
                                             if isPlayingThis && playerManager.playbackState == .playing {
                                                 MiniVisualizerView(isPlaying: true, tintColor: .white)
                                             } else {
                                                 Image(systemName: "music.note")
                                                     .foregroundColor(.white)
                                                     .font(.system(size: 14))
                                             }
                                         }
                                     }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlistTrack.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isPlayingThis ? .cyan : .white)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            Text(playlistTrack.artist)
                                                .font(.system(size: 11))
                                                .foregroundColor(.purple.opacity(0.8))
                                                .lineLimit(1)
                                            
                                            Text(playlistTrack.sourceName)
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Кнопка контекстного меню
                            Menu {
                                Button(action: {
                                    playlistManager.removeTrack(trackId: playlistTrack.id, from: PlaylistManager.favoritesUUID)
                                }) {
                                    Label("Удалить из избранного", systemImage: "heart.slash.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                playlistManager.removeTrack(trackId: playlistTrack.id, from: PlaylistManager.favoritesUUID)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
            }
        }
    }
    
    private func playFavoriteTrack(_ favoriteTrack: PlaylistTrack) {
        let playerTrack = favoriteTrack.toPlayerTrack()
        let favorites = playlistManager.playlists.first(where: { $0.id == PlaylistManager.favoritesUUID })
        let queue = (favorites?.tracks ?? []).map { $0.toPlayerTrack() }
        playerManager.play(track: playerTrack, in: queue)
    }
    
    /// Генерирует уникальный градиент для плейсхолдера обложки трека на основе хеша названия
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

// Расширение для конвертации
extension LocalTrack {
    func toPlaylistTrack() -> PlaylistTrack {
        return PlaylistTrack(
            id: id,
            title: title,
            artist: artist ?? source.displayName,
            sourceName: "Медиатека",
            localRelativePath: relativePath,
            remoteURLString: nil,
            googleFileId: nil,
            localCoverPath: localCoverPath,
            duration: duration
        )
    }
}

/// Карточка плейлиста в режиме сетки
struct PlaylistGridCard: View {
    let playlist: Playlist
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    var body: some View {
        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
            VStack(spacing: 12) {
                // Большая обложка плейлиста
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: playlist.id == PlaylistManager.favoritesUUID ? [.pink, .purple] : [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .opacity(0.85)
                    
                    Image(systemName: playlist.id == PlaylistManager.favoritesUUID ? "heart.fill" : "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
                .frame(height: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: (playlist.id == PlaylistManager.favoritesUUID ? Color.pink : Color.purple).opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Текст инфо
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(playlist.tracks.count) треков")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            if playlist.id != PlaylistManager.favoritesUUID {
                Button(role: .destructive, action: {
                    playlistManager.deletePlaylist(id: playlist.id)
                }) {
                    Label("Удалить плейлист", systemImage: "trash")
                }
            }
        }
    }
}

/// Анимация масштабирования кнопок при нажатии
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}