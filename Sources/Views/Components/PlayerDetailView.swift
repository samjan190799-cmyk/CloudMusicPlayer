import SwiftUI
import MediaPlayer

/// Детальное полноэкранное представление плеера
struct PlayerDetailView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var isPlayerExpanded: Bool
    
    @State private var isDraggingSlider = false
    @State private var progress: Double = 0.0
    
    // Анимация вращения обложки
    @State private var rotationAngle: Double = 0.0
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        guard let track = playerManager.currentTrack else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            ZStack {
                // Фоновый градиент с размытием
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.13, green: 0.06, blue: 0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Шапка плеера
                    HStack {
                        Button(action: {
                            withAnimation(.spring()) {
                                isPlayerExpanded = false
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Сейчас играет")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Заглушка для центрирования заголовка
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Виниловый проигрыватель с неоновым свечением
                    ZStack {
                        // Неоновое свечение сзади проигрывателя
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 290, height: 290)
                            .blur(radius: 20)
                        
                        // 1. Корпус проигрывателя (подложка/плита)
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.12, green: 0.12, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 290, height: 290)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 8)
                        
                        // Металлические уголки (акцент премиального дизайна)
                        Group {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .offset(x: -130, y: -130)
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .offset(x: 130, y: -130)
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .offset(x: -130, y: 130)
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .offset(x: 130, y: 130)
                        }
                        
                        // 2. Металлический круг под винилом (диск проигрывателя - platter)
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(white: 0.3), Color(white: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 250, height: 250)
                            .shadow(radius: 2)
                        
                        // 3. Сам виниловый диск (вращающийся)
                        ZStack {
                            // Тело винила (черный пластик или Обложка на весь диск)
                            if let coverURL = track.localCoverURL,
                               let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 240)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                            } else {
                                Circle()
                                    .fill(Color(white: 0.06))
                                    .frame(width: 240, height: 240)
                                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                                
                                // Бумажный ярлык по центру при отсутствии обложки
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 100, height: 100)
                                
                                // Первая буква названия трека по центру
                                Text(String(track.title.first ?? "🎵").uppercased())
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            
                            // Световые отблески (эффект винилового блеска) поверх обложки
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .clear, .white.opacity(0.12), .clear, .white.opacity(0.12), .clear
                                ]),
                                center: .center
                            )
                            .frame(width: 240, height: 240)
                            .clipShape(Circle())
                            
                            // Дорожки винила (тонкие концентрические круги) поверх обложки
                            ForEach(0..<15) { i in
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                    .frame(width: CGFloat(40 + i * 13), height: CGFloat(40 + i * 13))
                            }
                            
                            // Центральный шпиндель (металлический штырек)
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.white, .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 10, height: 10)
                                .shadow(radius: 1)
                            
                            // Маленькое центральное отверстие шпинделя
                            Circle()
                                .fill(Color.black)
                                .frame(width: 4, height: 4)
                        }
                        .rotationEffect(.degrees(rotationAngle))
                        
                        // 4. Тонарм (расположен в верхнем правом углу)
                        TonearmView(isPlaying: playerManager.playbackState == .playing)
                            .offset(x: 95, y: -75) // Размещаем базу тонарма сверху справа
                    }
                    .frame(width: 290, height: 290)
                    
                    Spacer()
                    
                    // Информация об исполнителе и треке с кнопкой "Избранное"
                    HStack(spacing: 0) {
                        // Заглушка слева для идеального центрирования текста
                        Color.clear
                            .frame(width: 32, height: 32)
                        
                        Spacer()
                        
                        VStack(spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Text(track.artist)
                                .font(.system(size: 16))
                                .foregroundColor(.purple.opacity(0.8))
                            
                            Text("Источник: \(track.sourceName)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        
                        Spacer()
                        
                        // Кнопка Избранного (сердечко)
                        Button(action: {
                            let playlistTrack = track.toPlaylistTrack()
                            playlistManager.toggleFavorite(track: playlistTrack)
                        }) {
                            Image(systemName: playlistManager.isTrackFavorite(trackId: track.id) ? "heart.fill" : "heart")
                                .font(.system(size: 26))
                                .foregroundColor(playlistManager.isTrackFavorite(trackId: track.id) ? .pink : .white.opacity(0.8))
                        }
                        .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 24)
                    
                    // Прогресс-бар воспроизведения
                    VStack(spacing: 8) {
                        Slider(
                            value: $progress,
                            in: 0...max(playerManager.duration, 1.0),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing {
                                    playerManager.seek(to: progress)
                                }
                            }
                        )
                        .accentColor(.cyan)
                        .padding(.horizontal, 24)
                        
                        HStack {
                            Text(formatTime(progress))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatTime(playerManager.duration))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 26)
                    }
                    
                    // Панель управления (Prev, Play, Next)
                    HStack(spacing: 28) {
                        // Shuffle button
                        Button(action: {
                            playerManager.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundColor(playerManager.isShuffleEnabled ? .cyan : .white.opacity(0.6))
                        }
                        
                        // Previous button
                        Button(action: {
                            playerManager.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Play / Pause с неоновым свечением
                        Button(action: {
                            playerManager.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .purple.opacity(0.6), radius: 10, x: 0, y: 0)
                                
                                Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .offset(x: playerManager.playbackState == .playing ? 0 : 2)
                            }
                        }
                        
                        // Next button
                        Button(action: {
                            playerManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        // Repeat button
                        Button(action: {
                            playerManager.toggleRepeatMode()
                        }) {
                            Image(systemName: playerManager.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.title3)
                                .foregroundColor(playerManager.repeatMode != .none ? .cyan : .white.opacity(0.6))
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Регулировка громкости
                    HStack(spacing: 12) {
                        Button(action: {
                            playerManager.isMuted.toggle()
                        }) {
                            Image(systemName: playerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        SystemVolumeSlider()
                            .frame(height: 32)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    
                    // Минималистичный аудиовизуализатор (прыгающие полоски)
                    HStack(spacing: 4) {
                        ForEach(0..<10) { index in
                            VisualizerBar(isPlaying: playerManager.playbackState == .playing)
                        }
                    }
                    .frame(height: 30)
                    .padding(.bottom, 20)
                }
            }
            .preferredColorScheme(.dark)
            .onReceive(timer) { _ in
                if playerManager.playbackState == .playing {
                    rotationAngle += 1.5 // Вращаем на 1.5 градуса каждые 0.1 секунды
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
        )
    }
    
    /// Форматирование секунд в формат ММ:СС
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Анимированная полоса аудиовизуализатора
struct VisualizerBar: View {
    let isPlaying: Bool
    @State private var heightMultiplier: CGFloat = 0.2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(
                colors: [.cyan, .purple],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 4, height: 30 * heightMultiplier)
            .animation(
                isPlaying ?
                    Animation.easeInOut(duration: Double.random(in: 0.2...0.5))
                        .repeatForever(autoreverses: true) :
                    .default,
                value: heightMultiplier
            )
            .onAppear {
                if isPlaying {
                    heightMultiplier = CGFloat.random(in: 0.3...1.0)
                }
            }
            .onChange(of: isPlaying) { playing in
                if playing {
                    heightMultiplier = CGFloat.random(in: 0.3...1.0)
                } else {
                    heightMultiplier = 0.2
                }
            }
    }
}

/// Реалистичный тонарм винилового проигрывателя
struct TonearmView: View {
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            // База тонарма (поворотное основание, неподвижное)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.2), Color(white: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                
                // Металлический центр базы
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.8), Color(white: 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 22, height: 22)
                
                // Крепежный винт в центре
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 6, height: 6)
            }
            
            // Рычаг тонарма (вращающийся вокруг центра базы)
            ZStack(alignment: .top) {
                // Изогнутый тонарм (металлическая трубка)
                Path { path in
                    path.move(to: CGPoint(x: 15, y: 15))
                    path.addLine(to: CGPoint(x: 15, y: 80))
                    path.addQuadCurve(to: CGPoint(x: -12, y: 145), control: CGPoint(x: 15, y: 120))
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(white: 0.65), Color(white: 0.95), Color(white: 0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .frame(width: 30, height: 160)
                
                // Картридж и игла на конце рычага
                ZStack {
                    // Корпус картриджа (ярко-оранжевый акцент)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.orange)
                        .frame(width: 10, height: 20)
                        .shadow(radius: 1)
                    
                    // Серебристый шелл (headshell)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(white: 0.8), Color(white: 0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 12, height: 5)
                        .offset(y: -8)
                    
                    // Маленький белый держатель звукоснимателя
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 5, height: 1.2)
                        .offset(x: 7, y: 1)
                }
                .rotationEffect(.degrees(-32))
                .offset(x: -28, y: 130)
            }
            .frame(width: 30, height: 160)
            .offset(y: 80) // Смещаем контейнер вниз, чтобы центр базы тонарма совпал с точкой (15, 15) внутри Path
            .rotationEffect(.degrees(isPlaying ? 25 : -5), anchor: .top)
            .animation(.spring(response: 1.0, dampingFraction: 0.75, blendDuration: 0), value: isPlaying)
        }
    }
}

/// Слайдер системной громкости iOS
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        
        // Кастомизируем внешний вид слайдера внутри MPVolumeView
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.minimumTrackTintColor = .systemPurple
            slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
            slider.thumbTintColor = .white
        }
        
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // Системный слайдер автоматически синхронизируется операционной системой
    }
}
