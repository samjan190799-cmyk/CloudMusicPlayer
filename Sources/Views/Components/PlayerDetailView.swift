import SwiftUI

/// Детальное полноэкранное представление плеера
struct PlayerDetailView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Binding var isPlayerExpanded: Bool
    
    @State private var isDraggingSlider = false
    @State private var dragTime: Double = 0.0
    
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
                    
                    // Обложка трека с неоновым свечением и вращением
                    ZStack {
                        // Неоновое свечение сзади обложки
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 260, height: 260)
                            .blur(radius: 30)
                        
                        // Вращающийся виниловый диск / обложка
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.04, green: 0.04, blue: 0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 250, height: 250)
                            .shadow(color: .purple.opacity(0.3), radius: 15, x: 0, y: 0)
                        
                        // Рисунки дорожек винила
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: 210, height: 210)
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            .frame(width: 170, height: 170)
                        
                        // Центральный ярлык
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                    .rotationEffect(.degrees(rotationAngle))
                    .frame(height: 270)
                    
                    Spacer()
                    
                    // Информация об исполнителе и треке
                    VStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                        
                        Text(track.artist)
                            .font(.system(size: 16))
                            .foregroundColor(.purple.opacity(0.8))
                        
                        Text("Источник: \(track.sourceName)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    
                    // Прогресс-бар воспроизведения
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? dragTime : playerManager.currentTime },
                                set: { newValue in
                                    isDraggingSlider = true
                                    dragTime = newValue
                                }
                            ),
                            in: 0...max(playerManager.duration, 1.0),
                            onEditingChanged: { editing in
                                if !editing {
                                    playerManager.seek(to: dragTime)
                                    isDraggingSlider = false
                                }
                            }
                        )
                        .accentColor(.cyan)
                        .padding(.horizontal, 24)
                        
                        HStack {
                            Text(formatTime(isDraggingSlider ? dragTime : playerManager.currentTime))
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
                        
                        Slider(value: $playerManager.volume, in: 0...1)
                            .accentColor(.purple)
                        
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
