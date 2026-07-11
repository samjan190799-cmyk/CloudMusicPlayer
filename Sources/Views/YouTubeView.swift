import SwiftUI

/// Вкладка поиска и прослушивания музыки через YouTube
struct YouTubeView: View {
    @ObservedObject var service = YouTubeService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    @State private var searchQuery = ""
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    
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
                    // Поисковая строка YouTube
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.red)
                        
                        TextField("Искать музыку в YouTube...", text: $searchQuery, onCommit: {
                            performSearch()
                        })
                        .foregroundColor(.white)
                        .submitLabel(.search)
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                            }) {
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
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    if service.isLoading {
                        Spacer()
                        ProgressView("Поиск в YouTube...")
                            .foregroundColor(.white)
                            .accentColor(.red)
                        Spacer()
                    } else if let error = service.errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button("Повторить поиск") {
                                performSearch()
                            }
                            .foregroundColor(.cyan)
                            .fontWeight(.bold)
                        }
                        Spacer()
                    } else if service.tracks.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.red.opacity(0.8))
                            
                            Text("Поиск музыки по всему миру")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Введите название песни, исполнителя или альбома для мгновенного стриминга и скачивания.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        // Результаты поиска
                        List {
                            ForEach(service.tracks) { track in
                                trackRow(track: track)
                            }
                            
                            if service.canLoadMore {
                                Button(action: {
                                    service.loadMore()
                                }) {
                                    HStack {
                                        Spacer()
                                        if service.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                        } else {
                                            Text("Загрузить еще...")
                                                .foregroundColor(.cyan)
                                                .fontWeight(.bold)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("YouTube Музыка")
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        service.search(query: searchQuery)
    }
    
    /// Ряд одного трека в результатах поиска
    private func trackRow(track: YouTubeTrack) -> some View {
        let downloadStatus = downloadManager.getDownloadStatus(for: track.id)
        let isPlaying = playerManager.currentTrack?.id == track.id
        
        return HStack(spacing: 12) {
            // Кнопка проигрывания трека
            Button(action: {
                playOnlineTrack(track)
            }) {
                HStack(spacing: 12) {
                    // Миниатюра видео
                    ZStack {
                        AsyncImage(url: URL(string: track.thumbnailUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.white.opacity(0.06)
                        }
                        .frame(width: 60, height: 44)
                        .cornerRadius(6)
                        .clipped()
                        
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                            .foregroundColor(isPlaying ? .cyan : .white)
                            .shadow(color: .black, radius: 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isPlaying ? .cyan : .white)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text(track.uploader)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            
                            Text(formatDuration(track.duration))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Кнопка контекстного меню плейлиста
            Menu {
                Button(action: {
                    let playlistTrack = track.toPlaylistTrack()
                    playlistManager.toggleFavorite(track: playlistTrack)
                }) {
                    if playlistManager.isTrackFavorite(trackId: track.id) {
                        Label("Удалить из избранного", systemImage: "heart.slash.fill")
                    } else {
                        Label("Добавить в избранное", systemImage: "heart.fill")
                    }
                }
                
                Button(action: {
                    selectedTrackForPlaylist = track.toPlaylistTrack()
                }) {
                    Label("Добавить в плейлист", systemImage: "music.note.list")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            
            // Кнопка / Индикатор скачивания
            ZStack {
                switch downloadStatus {
                case .notDownloaded:
                    Button(action: {
                        downloadManager.downloadYouTubeTrack(track)
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
                            downloadManager.cancelDownload(trackId: track.id)
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
                case .failed:
                    Button(action: {
                        downloadManager.downloadYouTubeTrack(track)
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
    
    private func playOnlineTrack(_ track: YouTubeTrack) {
        let playerTrack = PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.uploader,
            sourceName: "YouTube (Онлайн)",
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil
        )
        
        let queue = service.tracks.map { item in
            PlayerTrack(
                id: item.id,
                title: item.title,
                artist: item.uploader,
                sourceName: "YouTube (Онлайн)",
                localURL: nil,
                remoteURL: nil,
                googleFileId: nil
            )
        }
        
        playerManager.play(track: playerTrack, in: queue)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Расширение для конвертации YouTube-треков в трек плейлиста
extension YouTubeTrack {
    func toPlaylistTrack() -> PlaylistTrack {
        return PlaylistTrack(
            id: id,
            title: title,
            artist: uploader,
            sourceName: "YouTube",
            localRelativePath: nil,
            remoteURLString: nil,
            googleFileId: nil
        )
    }
}
