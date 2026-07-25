import SwiftUI
import PhotosUI

/// Экран просмотра деталей плейлиста
struct PlaylistDetailView: View {
    let playlist: Playlist
    
    @ObservedObject var playlistManager = PlaylistManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    // Получаем актуальный плейлист из менеджера
    var currentPlaylist: Playlist {
        playlistManager.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    var body: some View {
        ZStack {
            // Эмбиент фон
            AmbientBackgroundView(
                accentColor: currentPlaylist.id == PlaylistManager.favoritesUUID ? .pink : AppTheme.neonPurple,
                secondaryColor: AppTheme.neonCyan
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Заголовок и инфо о плейлисте
                playlistHeaderView
                
                if currentPlaylist.tracks.isEmpty {
                    Spacer()
                    emptyStateCard
                    Spacer()
                } else {
                    tracksListView
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        playlistManager.setCoverImage(image, for: currentPlaylist.id)
                        HapticManager.shared.triggerNotification(type: .success)
                    }
                }
            }
        }
    }

    // MARK: - Хедер Плейлиста

    private var playlistHeaderView: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                // Фоновое размытое свечение
                Circle()
                    .fill(LinearGradient(
                        colors: currentPlaylist.id == PlaylistManager.favoritesUUID ? [.pink, .purple] : [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .opacity(0.4)
                
                // Отображение обложки плейлиста
                Group {
                    if let coverURL = currentPlaylist.coverURL,
                       let uiImage = UIImage(contentsOfFile: coverURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(LinearGradient(
                                    colors: currentPlaylist.id == PlaylistManager.favoritesUUID ? [.pink, .purple] : [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 130, height: 130)
                            
                            Image(systemName: currentPlaylist.id == PlaylistManager.favoritesUUID ? "heart.fill" : "music.note.list")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)

                // Кнопка выбора фото
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.75))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.neonCyan)
                    }
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .offset(x: 6, y: 6)
            }
            .padding(.top, 12)
            
            VStack(spacing: 4) {
                Text(currentPlaylist.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(currentPlaylist.tracks.count) треков")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }
            
            // Кнопка "Воспроизвести всё"
            if !currentPlaylist.tracks.isEmpty {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playAll()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Воспроизвести всё")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .neonGlow(color: .cyan, radius: 8, opacity: 0.4)
                }
                .buttonStyle(SpringScaleButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Пустое Состояние

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.textMuted)
            
            Text("Плейлист пуст")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Перейдите в Медиатеку, Облако или YouTube, чтобы добавить треки.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(28)
        .liquidGlass(cornerRadius: 24, opacity: 0.4)
        .padding(.horizontal, 24)
    }

    // MARK: - Список Треков Плейлиста

    private var tracksListView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(currentPlaylist.tracks) { playlistTrack in
                    let isPlayingThis = playerManager.currentTrack?.id == playlistTrack.id && playerManager.playbackState == .playing
                    
                    Button(action: {
                        HapticManager.shared.triggerSelection()
                        playTrack(playlistTrack)
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                if let coverURL = playlistTrack.localCoverURL,
                                   let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 46, height: 46)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(placeholderGradient(for: playlistTrack.title))
                                        .frame(width: 46, height: 46)
                                    
                                    Image(systemName: isPlayingThis ? "pause.fill" : "music.note")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlistTrack.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(isPlayingThis ? .cyan : .white)
                                    .lineLimit(1)
                                
                                Text(playlistTrack.artist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textMuted)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.triggerSelection()
                                playlistManager.removeTrack(trackId: playlistTrack.id, from: currentPlaylist.id)
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(10)
                        .liquidGlass(cornerRadius: 18, opacity: 0.4)
                    }
                    .buttonStyle(SpringScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    /// Воспроизведение конкретного трека
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
    
    /// Генерирует уникальный градиент для обложки трека
    private func placeholderGradient(for title: String) -> LinearGradient {
        let colors: [[Color]] = [
            [.blue, .purple],
            [.purple, .pink],
            [.pink, .orange],
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
