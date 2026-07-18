import SwiftUI
import MediaPlayer

/// Экран детального воспроизведения трека с премиальным дизайном (Glassmorphism и неоновая подсветка)
struct PlayerDetailView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var isPlayerExpanded: Bool
    
    @State private var isDraggingSlider = false
    @State private var progress: Double = 0.0
    @AppStorage("playerInterfaceMode") private var playerInterfaceMode = "vinyl"
    
    @StateObject private var visualizerEngine = VisualizerEngine()
    
    @State private var rotationAngle: Double = 0.0
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if let track = playerManager.currentTrack {
                ZStack {
                    // 1. Премиальный фоновый градиент
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.08, blue: 0.18),
                            Color(red: 0.12, green: 0.05, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // 2. Медленно пульсирующие фоновые неоновые круги (создают объемное свечение)
                    neonBackgroundGlows
                    
                    VStack(spacing: 0) {
                        // Верхний Хедер
                        headerView
                            .padding(.top, 14)
                        
                        Spacer()
                        
                        // Режим визуализации (Винил / Обложка / Спектрограф)
                        playerInterfaceView(for: track)
                        
                        Spacer()
                        
                        // Информация о треке и Избранное
                        trackInfoView(for: track)
                            .padding(.bottom, 22)
                        
                        // Ползунок прогресса
                        progressSliderView
                            .padding(.bottom, 24)
                        
                        // Кнопки управления (Назад, Играть, Вперед, Шафл, Репит)
                        controlPanelView
                            .padding(.bottom, 24)
                        
                        // Слайдер громкости
                        volumeControlView
                            .padding(.bottom, 20)
                        
                        // Системный AirPlay Вывод Звука (как в дизайне AirPods Max)
                        airplayOutputView
                            .padding(.bottom, 16)
                    }
                }
            } else {
                EmptyView()
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            if playerManager.playbackState == .playing {
                rotationAngle += 1.5
            }
        }
        .onReceive(playerManager.$currentTime) { newTime in
            if !isDraggingSlider {
                progress = newTime
            }
        }
        .onAppear {
            progress = playerManager.currentTime
        }
    }
    
    // MARK: - Фоновое неоновое свечение (Динамический бэкграунд)
    
    private var neonBackgroundGlows: some View {
        let isPlaying = playerManager.playbackState == .playing
        let bassValue = isPlaying ? CGFloat(visualizerEngine.heights[0]) : 0.05
        
        return ZStack {
            // Верхнее фиолетовое свечение
            Circle()
                .fill(Color(red: 0.62, green: 0.31, blue: 0.87).opacity(0.18 + Double(bassValue * 0.15)))
                .frame(width: 320, height: 320)
                .blur(radius: 65 + bassValue * 30)
                .offset(x: -80, y: -100)
            
            // Нижнее синее свечение
            Circle()
                .fill(Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.15 + Double(bassValue * 0.12)))
                .frame(width: 300, height: 300)
                .blur(radius: 60 + bassValue * 25)
                .offset(x: 80, y: 120)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Верхний Хедер
    
    private var headerView: some View {
        HStack {
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isPlayerExpanded = false
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)
                        .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(Circle()))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Text("Now Playing")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .tracking(0.5)
            
            Spacer()
            
            // Кнопка переключения режимов вывода (Винил/Обложка/Спектрограф) в хедере
            Button(action: {
                cycleInterfaceMode()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)
                        .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(Circle()))
                    
                    Image(systemName: playerInterfaceMode == "vinyl" ? "record.circle" : (playerInterfaceMode == "cover" ? "photo.fill" : "waveform.path"))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Центральный режим визуализации (Режимы)
    
    @ViewBuilder
    private func playerInterfaceView(for track: PlayerTrack) -> some View {
        let isPlaying = playerManager.playbackState == .playing
        let bassScale = isPlaying ? CGFloat(1.0 + visualizerEngine.heights[0] * 0.08) : 1.0
        let bassBlur = isPlaying ? CGFloat(25.0 + visualizerEngine.heights[0] * 8.0) : 25.0
        
        if playerInterfaceMode == "vinyl" {
            let bassOpacity = isPlaying ? Double(0.15 + visualizerEngine.heights[0] * 0.15) : 0.15
            vinylPlayerView(for: track, bassScale: bassScale, bassBlur: bassBlur, bassOpacity: bassOpacity)
        } else if playerInterfaceMode == "cover" {
            let bassCoverOpacity = isPlaying ? Double(0.18 + visualizerEngine.heights[0] * 0.18) : 0.18
            coverArtView(for: track, bassScale: bassScale, bassBlur: bassBlur, bassCoverOpacity: bassCoverOpacity)
        } else {
            visualizerModeView
        }
    }
    
    // Режим 1: Виниловая пластинка
    private func vinylPlayerView(for track: PlayerTrack, bassScale: CGFloat, bassBlur: CGFloat, bassOpacity: Double) -> some View {
        ZStack {
            // Подложка неонового свечения
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.purple.opacity(bassOpacity))
                .frame(width: 290, height: 290)
                .scaleEffect(bassScale)
                .blur(radius: bassBlur)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])
            
            // Стеклянный стол проигрывателя (Glassmorphism)
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.04))
                .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24)))
                .frame(width: 290, height: 290)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
            
            // Металлические винтики по углам корпуса
            Group {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .offset(x: -130, y: -130)
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .offset(x: 130, y: -130)
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .offset(x: -130, y: 130)
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .offset(x: 130, y: 130)
            }
            
            // Пластинка (Винил)
            Circle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.22), Color(white: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 250, height: 250)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // Звуковые дорожки на пластинке
            ForEach(0..<12) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: CGFloat(60 + i * 15), height: CGFloat(60 + i * 15))
            }
            
            // Обложка по центру пластинки (круглая)
            ZStack {
                if let coverURL = track.localCoverURL, let uiImage = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 90, height: 90)
                    
                    Text(String(track.title.first ?? "M").uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Шпиндель (центр пластинки)
                Circle()
                    .fill(LinearGradient(
                        colors: [.white, .gray],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
            }
            .rotationEffect(.degrees(rotationAngle))
            
            // Тонарм проигрывателя (с анимацией перемещения)
            TonearmView(isPlaying: playerManager.playbackState == .playing)
                .offset(x: 95, y: -75)
        }
        .frame(width: 290, height: 290)
        .contentShape(Rectangle())
        .onTapGesture {
            cycleInterfaceMode()
        }
    }
    
    // Режим 2: Обложка (Парящая карточка из макета Dolby Atmos)
    private func coverArtView(for track: PlayerTrack, bassScale: CGFloat, bassBlur: CGFloat, bassCoverOpacity: Double) -> some View {
        ZStack {
            // Подложка неонового свечения
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.62, green: 0.31, blue: 0.87).opacity(bassCoverOpacity))
                .frame(width: 280, height: 280)
                .scaleEffect(bassScale)
                .blur(radius: bassBlur)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])
            
            // Сама обложка
            ZStack(alignment: .top) {
                if let coverURL = track.localCoverURL, let uiImage = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 275, height: 275)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.08, blue: 0.35), Color(red: 0.05, green: 0.08, blue: 0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 275, height: 275)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 84))
                        .foregroundColor(.white.opacity(0.2))
                        .frame(width: 275, height: 275, alignment: .center)
                }
                
                // Верхний оверлей плашки: NEW MUSIC
                HStack {
                    Text("NEW MUSIC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(14)
                
                // Нижний оверлей плашки: Dolby Atmos (как на макете)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "badge.plus.radiowaves.right")
                            Text("Dolby Atmos")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.bottom, 14)
                }
            }
            .frame(width: 275, height: 275)
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
        }
        .frame(width: 290, height: 290)
        .contentShape(Rectangle())
        .onTapGesture {
            cycleInterfaceMode()
        }
    }
    
    // Режим 3: Спектрограф
    private var visualizerModeView: some View {
        VStack(spacing: 12) {
            RealtimeVisualizerView(engine: visualizerEngine)
                .frame(height: 100)
                
            CircularVisualizerView(engine: visualizerEngine, isPlaying: playerManager.playbackState == .playing)
        }
        .frame(width: 290, height: 290)
        .contentShape(Rectangle())
        .onTapGesture {
            cycleInterfaceMode()
        }
    }
    
    // MARK: - Информация о треке
    
    private func trackInfoView(for track: PlayerTrack) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Кнопка Избранного (сердечко в стеклянной капсуле)
            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                let playlistTrack = track.toPlaylistTrack()
                playlistManager.toggleFavorite(track: playlistTrack)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                        .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(Circle()))
                    
                    Image(systemName: playlistManager.isTrackFavorite(trackId: track.id) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(playlistManager.isTrackFavorite(trackId: track.id) ? .pink : .white)
                        .shadow(color: playlistManager.isTrackFavorite(trackId: track.id) ? .pink.opacity(0.4) : .clear, radius: 4)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Слайдер времени прогресса
    
    private var progressSliderView: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Задняя полоса слайдера
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    
                    // Заливка прогресса
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(progress / max(playerManager.duration, 1.0)) * geometry.size.width, height: 4)
                        .shadow(color: .cyan.opacity(0.5), radius: 3)
                    
                    // Бегунок слайдера (как в дизайне)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .offset(x: CGFloat(progress / max(playerManager.duration, 1.0)) * geometry.size.width - 7)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingSlider = true
                                    let percentage = min(max(0, value.location.x / geometry.size.width), 1.0)
                                    progress = Double(percentage) * max(playerManager.duration, 1.0)
                                }
                                .onEnded { value in
                                    isDraggingSlider = false
                                    playerManager.seek(to: progress)
                                }
                        )
                }
            }
            .frame(height: 14)
            .padding(.horizontal, 24)
            
            HStack {
                Text(formatTime(progress))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                
                Spacer()
                
                Text(formatTime(playerManager.duration))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 26)
        }
    }
    
    // MARK: - Панель кнопок управления
    
    private var controlPanelView: some View {
        HStack(spacing: 20) {
            // Кнопка Shuffle
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.toggleShuffle()
            }) {
                controlButtonBackground(icon: "shuffle", isSelected: playerManager.isShuffleEnabled)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Кнопка Назад
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.previousTrack()
            }) {
                controlButtonBackground(icon: "backward.fill", size: 50, iconSize: 16)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Центральная кнопка Воспроизведения (большая с градиентным свечением)
            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                playerManager.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.62, green: 0.31, blue: 0.87), Color(red: 0.0, green: 0.5, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: Color(red: 0.62, green: 0.31, blue: 0.87).opacity(0.55), radius: 14, x: 0, y: 0)
                    
                    Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: playerManager.playbackState == .playing ? 0 : 2)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Кнопка Вперед
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.nextTrack()
            }) {
                controlButtonBackground(icon: "forward.fill", size: 50, iconSize: 16)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Кнопка Repeat
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.toggleRepeatMode()
            }) {
                controlButtonBackground(icon: playerManager.repeatMode == .one ? "repeat.1" : "repeat", isSelected: playerManager.repeatMode != .none)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    private func controlButtonBackground(icon: String, size: CGFloat = 46, iconSize: CGFloat = 14, isSelected: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.cyan.opacity(0.12) : Color.white.opacity(0.06))
                .frame(width: size, height: size)
                .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(Circle()))
            
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(isSelected ? .cyan : .white)
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Слайдер Громкости
    
    private var volumeControlView: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.isMuted.toggle()
            }) {
                Image(systemName: playerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 13))
            }
            .buttonStyle(ScaleButtonStyle())
            
            SystemVolumeSlider()
                .frame(height: 32)
            
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 13))
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Панель AirPlay
    
    private var airplayOutputView: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplayaudio")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 13, weight: .semibold))
            
            Text("AirPlay: iPhone Device")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .tracking(0.3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .background(VisualEffectBlur(material: .systemUltraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func cycleInterfaceMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            if playerInterfaceMode == "vinyl" {
                playerInterfaceMode = "cover"
            } else if playerInterfaceMode == "cover" {
                playerInterfaceMode = "visualizer"
            } else {
                playerInterfaceMode = "vinyl"
            }
            HapticManager.shared.triggerImpact(style: .medium)
        }
    }
}

// MARK: - Системный VolumeSlider

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView()
        
        // Кастомизация внешнего вида слайдера громкости под дизайн
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.minimumTrackTintColor = .cyan
            slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
            slider.thumbTintColor = .white
        }
        
        volumeView.showsRouteButton = false // Скрываем стандартную кнопку AirPlay, так как у нас свой оверлей
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
