import SwiftUI

/// Экран просмотра деталей плейлиста
struct PlaylistDetailView: View {
    let playlist: Playlist
    
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Получаем актуальный плейлист из менеджера (так как переданный в struct объект может устареть после удаления треков)
    var currentPlaylist: Playlist {
        playlistManager.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    var body: some View {
        ZStack {
            // Фон
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Заголовок и инфо о плейлисте
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: playlist.id == PlaylistManager.favoritesUUID ? [.pink, .purple] : [.purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .shadow(color: playlist.id == PlaylistManager.favoritesUUID ? .pink.opacity(0.4) : .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: playlist.id == PlaylistManager.favoritesUUID ? "heart.fill" : "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    
                    Text(currentPlaylist.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(currentPlaylist.tracks.count) треков")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Кнопка "Воспроизвести всё"
                    if !currentPlaylist.tracks.isEmpty {
                        Button(action: {
                            playAll()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Воспроизвести всё")
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(LinearGradient(
                                colors: [.purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .cornerRadius(28)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 16)
                
                if currentPlaylist.tracks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("Плейлист пуст")
                            .foregroundColor(.gray)
                        Text("Перейдите в Медиатеку или Облако, чтобы добавить треки.")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    // Список треков
                    List {
                        ForEach(currentPlaylist.tracks) { playlistTrack in
                            let isPlayingThis = playerManager.currentTrack?.id == playlistTrack.id
                            
                            Button(action: {
                                playTrack(playlistTrack)
                            }) {
                                HStack(spacing: 12) {
                                     ZStack {
                                         if let coverURL = playlistTrack.localCoverURL,
                                            let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                             Image(uiImage: uiImage)
                                                 .resizable()
                                                 .scaledToFill()
                                                 .frame(width: 40, height: 40)
                                                 .clipShape(RoundedRectangle(cornerRadius: 8))
                                         } else {
                                             RoundedRectangle(cornerRadius: 8)
                                                 .fill(Color.white.opacity(0.06))
                                                 .frame(width: 40, height: 40)
                                             
                                             Image(systemName: isPlayingThis ? "speaker.wave.3.fill" : "music.note")
                                                 .foregroundColor(isPlayingThis ? .cyan : .white)
                                         }
                                     }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlistTrack.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(isPlayingThis ? .cyan : .white)
                                            .lineLimit(1)
                                        
                                        Text(playlistTrack.artist)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    playlistManager.removeTrack(trackId: playlistTrack.id, from: currentPlaylist.id)
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
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
    
    /// Воспроизведение конкретного трека в контексте очереди плейлиста
    private func playTrack(_ track: PlaylistTrack) {
        let playerTrack = track.toPlayerTrack()
        let queue = currentPlaylist.tracks.map { $0.toPlayerTrack() }
        playerManager.play(track: playerTrack, in: queue)
    }
    
    /// Воспроизведение всего плейлиста сначала
    private func playAll() {
        guard let first = currentPlaylist.tracks.first else { return }
        playTrack(first)
    }
}

// Вспомогательное расширение для приведения типов
extension PlaylistTrack {
    func toPlayerTrack() -> PlayerTrack {
        return PlayerTrack(
            id: id,
            title: title,
            artist: artist,
            sourceName: sourceName,
            localURL: localURL,
            remoteURL: remoteURL,
            googleFileId: googleFileId,
            localCoverURL: localCoverURL
        )
    }
}
