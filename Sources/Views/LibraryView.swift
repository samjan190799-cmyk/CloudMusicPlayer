import SwiftUI

/// Главный экран (Today / Медиатека) в стиле премиального интерфейса с нежным неоновым стеклом (Glassmorphism)
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
    @State private var selectedSection = 0
    
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
                        // 1. Хедер (Today + Кнопка Профиля)
                        headerView
                        
                        // 2. Секция Playlists (Горизонтальный скролл больших стеклянных карточек)
                        playlistsSection
                        
                        // 3. Секция Best new songs (Вертикальный список закругленных рядов)
                        bestNewSongsSection
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
    
    // MARK: - Хедер (Today + Профиль)
    
    private var headerView: some View {
        HStack {
            Text("Главная")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
            }) {
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Circle()
                        .fill(Color.white.opacity(0.12))
                    
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 17, weight: .semibold))
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
    
    // MARK: - Секция Playlists (Горизонтальный скролл карточек)
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Плейлисты")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    // Карточка 1 (New Music Mix)
                    playlistCard(
                        title: "New Music Mix",
                        subtitle: "MUSIC FOR MENG",
                        gradientColors: [
                            Color(red: 0.1, green: 0.15, blue: 0.45),
                            Color(red: 0.35, green: 0.12, blue: 0.65),
                            Color(red: 0.05, green: 0.05, blue: 0.2)
                        ]
                    )
                    
                    // Карточка 2 (Favorite Mix)
                    playlistCard(
                        title: "Favorite Mix",
                        subtitle: "MUSIC FOR YOU",
                        gradientColors: [
                            Color(red: 0.05, green: 0.25, blue: 0.55),
                            Color(red: 0.15, green: 0.1, blue: 0.4),
                            Color(red: 0.2, green: 0.05, blue: 0.45)
                        ]
                    )

                    // Карточка 3 (Discover Mix)
                    playlistCard(
                        title: "Chillout Mix",
                        subtitle: "DAILY SELECTION",
                        gradientColors: [
                            Color(red: 0.4, green: 0.15, blue: 0.6),
                            Color(red: 0.1, green: 0.3, blue: 0.65),
                            Color(red: 0.08, green: 0.06, blue: 0.22)
                        ]
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private func playlistCard(title: String, subtitle: String, gradientColors: [Color]) -> some View {
        ZStack(alignment: .bottom) {
            // Абстрактный волнистый нежный фон карточки без конкретных песен/обложек
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Декоративные волнистые световые пятна (Fluid Art)
                GeometryReader { geo in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height * 0.3))
                        path.addCurve(
                            to: CGPoint(x: geo.size.width, y: geo.size.height * 0.7),
                            control1: CGPoint(x: geo.size.width * 0.5, y: 0),
                            control2: CGPoint(x: geo.size.width * 0.6, y: geo.size.height)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .cyan.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    
                    Circle()
                        .fill(Color.cyan.opacity(0.25))
                        .blur(radius: 35)
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.1)
                }
            }
            .frame(width: 230, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            
            // Нижняя плавающая матовая стеклянная плашка
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Фиолетовая неоновая кнопка Play со свечением
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.3, blue: 1.0), Color(red: 0.45, green: 0.2, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 0.65, green: 0.3, blue: 1.0).opacity(0.6), radius: 10, x: 0, y: 4)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(SpringScaleButtonStyle())
            }
            .padding(16)
            .frame(width: 230)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.12, green: 0.12, blue: 0.28).opacity(0.65)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .frame(width: 230, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Секция Best new songs (Чистый интерфейсный список)
    
    private var bestNewSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Новые треки")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                // Карточка-ряд 1
                songRowCard(
                    title: "Post Mates",
                    artist: "Jarami",
                    gradientColors: [Color(red: 0.15, green: 0.1, blue: 0.35), Color(red: 0.05, green: 0.2, blue: 0.45)]
                )
                
                // Карточка-ряд 2
                songRowCard(
                    title: "Freaky Deaky",
                    artist: "Tyga & Doja Cat",
                    gradientColors: [Color(red: 0.25, green: 0.08, blue: 0.4), Color(red: 0.1, green: 0.1, blue: 0.3)]
                )
                
                // Карточка-ряд 3
                songRowCard(
                    title: "Shivers",
                    artist: "Ed Sheeran",
                    gradientColors: [Color(red: 0.08, green: 0.2, blue: 0.5), Color(red: 0.3, green: 0.1, blue: 0.4)]
                )
                
                // Карточка-ряд 4
                songRowCard(
                    title: "As It Was",
                    artist: "Harry Styles",
                    gradientColors: [Color(red: 0.35, green: 0.15, blue: 0.5), Color(red: 0.05, green: 0.12, blue: 0.3)]
                )
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func songRowCard(title: String, artist: String, gradientColors: [Color]) -> some View {
        HStack(spacing: 16) {
            // Квадратный абстрактный неоновый плейсхолдер 56х56 с закруглением
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(x: 1)
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(artist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.triggerSelection()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                    
                    Image(systemName: "ellipsis")
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
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}