import SwiftUI
import MediaPlayer

/// Детальное полноэкранное представление плеера
struct PlayerDetailView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var isPlayerExpanded: Bool
    
    @State private var isDraggingSlider = false
    @State private var progress: Double = 0.0
    @AppStorage("playerInterfaceMode") private var playerInterfaceMode = "vinyl"
    
    // Движок визуализации
    @StateObject private var visualizerEngine = VisualizerEngine()
    
    // Анимация вращения обложки
    @State private var rotationAngle: Double = 0.0
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        guard let track = playerManager.currentTrack else {
            return AnyView(EmptyView())
        }
        
        let isPlaying = playerManager.playbackState == .playing
        let bassScale = isPlaying ? CGFloat(1.0 + visualizerEngine.heights[0] * 0.12) : 1.0
        let bassBlur = isPlaying ? CGFloat(20.0 + visualizerEngine.heights[0] * 10.0) : 20.0
        let bassOpacity = isPlaying ? Double(0.12 + visualizerEngine.heights[0] * 0.15) : 0.12
        let bassCoverOpacity = isPlaying ? Double(0.15 + visualizerEngine.heights[0] * 0.18) : 0.15
        
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
                            HapticManager.shared.triggerImpact(style: .light)
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
                        .buttonStyle(ScaleButtonStyle())
                        
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
                    
                    if playerInterfaceMode == "vinyl" {
                        // Виниловый проигрыватель с неоновым свечением
                        ZStack {
                            // Неоновое свечение сзади проигрывателя (реагирует на басы)
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.purple.opacity(bassOpacity))
                                .frame(width: 290, height: 290)
                                .scaleEffect(bassScale)
                                .blur(radius: bassBlur)
                                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])
                            
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            cycleInterfaceMode()
                        }
                    } else if playerInterfaceMode == "cover" {
                        // Режим крупной обложки (Apple Music style)
                        ZStack {
                            // Неоновое свечение сзади обложки (реагирует на басы)
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.purple.opacity(bassCoverOpacity))
                                .frame(width: 280, height: 280)
                                .scaleEffect(bassScale)
                                .blur(radius: bassBlur)
                                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])
                            
                            if let coverURL = track.localCoverURL,
                               let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 270, height: 270)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 270, height: 270)
                                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "music.note")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .frame(width: 290, height: 290)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            cycleInterfaceMode()
                        }
                    } else {
                        // Режим визуализатора
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
                            HapticManager.shared.triggerImpact(style: .medium)
                            let playlistTrack = track.toPlaylistTrack()
                            playlistManager.toggleFavorite(track: playlistTrack)
                        }) {
                            Image(systemName: playlistManager.isTrackFavorite(trackId: track.id) ? "heart.fill" : "heart")
                                .font(.system(size: 26))
                                .foregroundColor(playlistManager.isTrackFavorite(trackId: track.id) ? .pink : .white.opacity(0.8))
                        }
                        .frame(width: 32, height: 32)
                        .buttonStyle(ScaleButtonStyle())
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
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundColor(playerManager.isShuffleEnabled ? .cyan : .white.opacity(0.6))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Previous button
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Play / Pause с неоновым свечением
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
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
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Next button
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Repeat button
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.toggleRepeatMode()
                        }) {
                            Image(systemName: playerManager.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.title3)
                                .foregroundColor(playerManager.repeatMode != .none ? .cyan : .white.opacity(0.6))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.bottom, 10)
                    
                    // Регулировка громкости
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.isMuted.toggle()
                        }) {
                            Image(systemName: playerManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        SystemVolumeSlider()
                            .frame(height: 32)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
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
    
    /// Переключение режимов интерфейса плеера с виброоткликом
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

/// Движок спектральной визуализации
class VisualizerEngine: ObservableObject {
    @Published var heights: [CGFloat] = Array(repeating: 0.03, count: 28)
    @Published var peaks: [CGFloat] = Array(repeating: 0.03, count: 28)
    
    private var peakDownSpeeds: [CGFloat] = Array(repeating: 0.0, count: 28)
    private var timer: Timer?
    private var time: CGFloat = 0.0
    private let numberOfBars = 28
    
    init() {
        startTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func update() {
        let isPlaying = AudioPlayerManager.shared.playbackState == .playing
        
        // Энергосбережение: если музыка на паузе и полосы опустились, ничего не пересчитываем
        let allZero = heights.allSatisfy { $0 <= 0.035 } && peaks.allSatisfy { $0 <= 0.035 }
        if !isPlaying && allZero {
            return
        }
        
        time += 0.15
        
        for i in 0..<numberOfBars {
            var target: CGFloat = 0.03
            
            if isPlaying {
                // Симулируем реалистичные частотные спектры
                let x = time + CGFloat(i) * 0.35
                
                if i < 6 {
                    // Басы (левая часть): ритмичные всплески + низкочастотный шум
                    let beat = abs(sin(time * 2.8))
                    let subBeat = abs(cos(time * 1.4)) * 0.3
                    let randomComponent = CGFloat.random(in: -0.15...0.25)
                    
                    let scale = CGFloat(6 - i) / 6.0
                    target = (beat * 0.65 + subBeat + randomComponent) * scale
                    target = max(target, 0.15)
                } else if i < 18 {
                    // Средние частоты: имитация голоса и инструментов
                    let wave1 = sin(x * 2.2) * 0.3
                    let wave2 = cos(x * 4.1) * 0.2
                    let noise = CGFloat.random(in: 0.0...0.3)
                    target = abs(wave1 + wave2) + noise + 0.1
                } else {
                    // Высокие частоты: тарелки и шумы
                    let wave1 = sin(x * 6.5) * 0.15
                    let noise = CGFloat.random(in: 0.0...0.4)
                    target = abs(wave1) + noise + 0.05
                }
            } else {
                target = 0.03
            }
            
            // Сглаживание движения
            let interpolationSpeed: CGFloat = isPlaying ? 0.28 : 0.12
            heights[i] = heights[i] + (target - heights[i]) * interpolationSpeed
            
            // Физика гравитации для пиков (Falling Peaks)
            if heights[i] >= peaks[i] {
                peaks[i] = heights[i]
                peakDownSpeeds[i] = 0.0
            } else {
                peakDownSpeeds[i] += 0.0055
                peaks[i] = max(peaks[i] - peakDownSpeeds[i], heights[i])
            }
            
            heights[i] = min(max(heights[i], 0.03), 1.0)
            peaks[i] = min(max(peaks[i], 0.03), 1.0)
        }
    }
}

/// Реалистичный спектрограф с физикой гравитации пиков
struct RealtimeVisualizerView: View {
    @ObservedObject var engine: VisualizerEngine
    let maxHeight: CGFloat = 100.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3.5) {
            ForEach(0..<engine.heights.count, id: \.self) { index in
                let barHeight = maxHeight * engine.heights[index]
                let peakOffset = maxHeight * engine.peaks[index]
                
                ZStack(alignment: .bottom) {
                    // Фоновая подложка
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 5, height: maxHeight)
                    
                    // Столбец спектра
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(
                            colors: [.purple, .cyan, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 5, height: barHeight)
                        .shadow(color: Color.cyan.opacity(0.25), radius: 2)
                    
                    // Пиковый маркер (Falling Peak)
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Color.white)
                        .frame(width: 5, height: 1.5)
                        .shadow(color: Color.white.opacity(0.8), radius: 1)
                        .offset(y: -peakOffset)
                }
                .frame(height: maxHeight)
            }
        }
    }
}

/// Круговой визуализатор с пульсацией и радиальным спектром
struct CircularVisualizerView: View {
    @ObservedObject var engine: VisualizerEngine
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            // Эффект расходящихся кругов (Ripple)
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.cyan.opacity(isPlaying ? 0.15 / Double(i + 1) : 0.03), lineWidth: 1.2)
                    .scaleEffect(isPlaying ? CGFloat(1.1 + Double(i) * 0.2 + Double(engine.heights[0]) * 0.1) : 1.0)
                    .frame(width: 70, height: 70)
                    .blur(radius: 0.5)
                    .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.65), value: engine.heights[0])
            }
            
            // Круговой спектр из лучей
            ForEach(0..<24, id: \.self) { j in
                let val = engine.heights[j % engine.heights.count]
                let rayHeight = 6 + 22 * val
                
                Capsule()
                    .fill(LinearGradient(
                        colors: [.cyan, .purple.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 2.5, height: rayHeight)
                    .offset(y: -36 - (rayHeight / 2))
                    .rotationEffect(.degrees(Double(j) * 15.0))
            }
            
            // Central pulsing circle
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 62, height: 62)
                    .shadow(color: Color.purple.opacity(0.3), radius: 6)
                
                Circle()
                    .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                    .frame(width: 62, height: 62)
                
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.cyan)
                    .shadow(color: Color.cyan.opacity(0.4), radius: 3)
            }
            .scaleEffect(isPlaying ? 1.0 + engine.heights[0] * 0.1 : 1.0)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: engine.heights[0])
        }
        .frame(width: 140, height: 140)
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

/// Анимация масштабирования кнопок при нажатии
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
