import SwiftUI

/// Выделенная вкладка Аудиокниг с стеклянным стилем Liquid Glass 2026 и запоминанием прогресса
struct AudiobooksView: View {
    @ObservedObject var service = YouTubeService.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    @State private var searchQuery = ""
    @State private var selectedGenre = "Бестселлеры"
    @State private var selectedTrackForPlaylist: PlaylistTrack? = nil
    
    private let audiobookGenres = [
        ("⭐ Бестселлеры", "Бестселлеры"),
        ("🚀 Фантастика & Фэнтези", "Фантастика"),
        ("🔍 Детективы & Триллеры", "Детективы"),
        ("📖 Классика", "Классика"),
        ("💡 Саморазвитие", "Саморазвитие"),
        ("💼 Бизнес & Успех", "Бизнес")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Динамический эмбиент фон
                AmbientBackgroundView(accentColor: AppTheme.neonPurple, secondaryColor: AppTheme.neonCyan)
                
                VStack(spacing: 0) {
                    // Хедер Аудиокниг
                    headerView
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Переключатель жанров
                            genrePickerView
                            
                            // Список выгруженных аудиокниг
                            audiobooksListSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedTrackForPlaylist) { track in
                AddToPlaylistView(track: track)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if service.audiobookTracks.isEmpty {
                service.fetchAudiobooks(category: selectedGenre)
            }
        }
    }
    
    // MARK: - Хедер
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Аудиокниги")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Слушайте бестселлеры с запоминанием места")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(AppTheme.glassSurface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.neonPurple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Поисковая строка для Аудиокниг
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textMuted)
                
                TextField("Поиск аудиокниги или автора...", text: $searchQuery, onCommit: {
                    performAudiobookSearch()
                })
                .foregroundColor(.white)
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 16, opacity: 0.4)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Переключатель Жанров
    
    private var genrePickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(audiobookGenres, id: \.1) { name, key in
                    let isSelected = selectedGenre == key
                    Button(action: {
                        selectedGenre = key
                        HapticManager.shared.triggerSelection()
                        service.fetchAudiobooks(category: key)
                    }) {
                        Text(name)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : AppTheme.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if isSelected {
                                        AppTheme.accentGradient
                                            .clipShape(Capsule())
                                            .neonGlow(color: AppTheme.neonPurple, radius: 6, opacity: 0.4)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                    }
                                }
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Список Аудиокниг
    
    private var audiobooksListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonPurple))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if service.audiobookTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Аудиокниги не найдены. Выберите другой жанр или воспользуйтесь поиском.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(service.audiobookTracks) { track in
                        audiobookRowView(for: track)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func audiobookRowView(for track: YouTubeTrack) -> some View {
        let playerTrack = convertToPlayerTrack(track)
        let isPlayingThis = playerManager.currentTrack?.id == track.id && playerManager.playbackState == .playing
        let savedPos = UserDefaults.standard.double(forKey: "playhead_\(track.id)")
        
        return HStack(spacing: 12) {
            ZStack {
                YouTubeThumbnail(videoId: track.id, width: 56, height: 56)
                
                if isPlayingThis {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 56, height: 56)
                        
                        MiniVisualizerView(isPlaying: true, tintColor: AppTheme.neonPurple)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.uploader)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(formatDuration(track.duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                    
                    if savedPos > 5 {
                        Text("•")
                            .foregroundColor(AppTheme.neonPurple)
                        
                        Text("📌 Запомнено: \(formatDuration(Int(savedPos)))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.neonPurple)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                playAudiobook(track)
            }) {
                Image(systemName: isPlayingThis ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.neonPurple)
            }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 18, opacity: 0.35)
        .onTapGesture {
            playAudiobook(track)
        }
    }
    
    private func performAudiobookSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        service.fetchAudiobooks(category: searchQuery)
    }
    
    private func playAudiobook(_ track: YouTubeTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        let playerTrack = convertToPlayerTrack(track)
        let allTracks = service.audiobookTracks.map { convertToPlayerTrack($0) }
        playerManager.play(track: playerTrack, in: allTracks)
    }
    
    private func convertToPlayerTrack(_ track: YouTubeTrack) -> PlayerTrack {
        PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.uploader,
            sourceName: "Аудиокниги",
            localURL: nil,
            remoteURL: nil,
            googleFileId: nil,
            localCoverURL: nil,
            duration: Double(track.duration)
        )
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return String(format: "%dч %02dм", hrs, mins)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}
