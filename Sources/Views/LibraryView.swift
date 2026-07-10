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
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    if selectedSection == 0 {
                        // Раздел "Треки"
                        tracksSection
                    } else {
                        // Раздел "Плейлисты"
                        playlistsSection
                    }
                }
            }
            .navigationTitle(selectedSection == 0 ? "Моя Медиатека" : "Мои Плейлисты")
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
                    } else {
                        Button(action: {
                            showingCreatePlaylistAlert = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
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
                                    // Иконка
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: isPlayingThis ? "speaker.wave.3.fill" : "music.note")
                                            .foregroundColor(isPlayingThis ? .cyan : .white)
                                    }
                                    
                                    // Название трека и размер
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localTrack.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isPlayingThis ? .cyan : .white)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            Text(localTrack.source == .google ? "Google Drive" : "Яндекс Диск")
                                                .font(.system(size: 11))
                                                .foregroundColor(.purple.opacity(0.8))
                                            
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
                List {
                    ForEach(playlistManager.playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(
                                            colors: [.purple, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 48, height: 48)
                                        .opacity(0.7)
                                    
                                    Image(systemName: "music.note.list")
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
                            Button(role: .destructive) {
                                playlistManager.deletePlaylist(id: playlist.id)
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
    
    /// Воспроизведение локального трека
    private func playLocalTrack(_ localTrack: LocalTrack) {
        let playerTrack = PlayerTrack(
            id: localTrack.id,
            title: localTrack.title,
            artist: localTrack.source == .google ? "Google Drive" : "Яндекс Диск",
            sourceName: "Офлайн Медиатека",
            localURL: localTrack.localURL,
            remoteURL: nil,
            googleFileId: nil
        )
        
        let queue = downloadManager.localTracks.map { track in
            PlayerTrack(
                id: track.id,
                title: track.title,
                artist: track.source == .google ? "Google Drive" : "Яндекс Диск",
                sourceName: "Офлайн Медиатека",
                localURL: track.localURL,
                remoteURL: nil,
                googleFileId: nil
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
}

// Расширение для конвертации
extension LocalTrack {
    func toPlaylistTrack() -> PlaylistTrack {
        return PlaylistTrack(
            id: id,
            title: title,
            artist: source == .google ? "Google Drive" : "Яндекс Диск",
            sourceName: "Медиатека",
            localRelativePath: relativePath,
            remoteURLString: nil,
            googleFileId: nil
        )
    }
}
