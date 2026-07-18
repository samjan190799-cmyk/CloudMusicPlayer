import SwiftUI
import MediaPlayer

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
                                                                                LinearGradient(
                                                                                                            colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.13, green: 0.06, blue: 0.22)],
                                                                                                            startPoint: .top,
                                                                                                            endPoint: .bottom
                                                                                )
                                                                                .ignoresSafeArea()

                                                                                VStack(spacing: 24) {
                                                                                                            headerView
                                                                                                            
                                                                                                            Spacer()
                                                                                                            
                                                                                                            playerInterfaceView(for: track)
                                                                                                            
                                                                                                            Spacer()
                                                                                                            
                                                                                                            trackInfoView(for: track)
                                                                                                            
                                                                                                            progressSliderView
                                                                                                            
                                                                                                            controlPanelView
                                                                                                            
                                                                                                            volumeControlView
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
        private var headerView: some View {
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

                                    Text("Now Playing")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
        }

        @ViewBuilder
        private func playerInterfaceView(for track: PlayerTrack) -> some View {
                    let isPlaying = playerManager.playbackState == .playing
                    let bassScale = isPlaying ? CGFloat(1.0 + visualizerEngine.heights[0] * 0.12) : 1.0
                    let bassBlur = isPlaying ? CGFloat(20.0 + visualizerEngine.heights[0] * 10.0) : 20.0

                    if playerInterfaceMode == "vinyl" {
                                    let bassOpacity = isPlaying ? Double(0.12 + visualizerEngine.heights[0] * 0.15) : 0.12
                                    vinylPlayerView(for: track, bassScale: bassScale, bassBlur: bassBlur, bassOpacity: bassOpacity)
                    } else if playerInterfaceMode == "cover" {
                                    let bassCoverOpacity = isPlaying ? Double(0.15 + visualizerEngine.heights[0] * 0.18) : 0.15
                                    coverArtView(for: track, bassScale: bassScale, bassBlur: bassBlur, bassCoverOpacity: bassCoverOpacity)
                    } else {
                                    visualizerModeView
                    }
        }
        private func vinylPlayerView(for track: PlayerTrack, bassScale: CGFloat, bassBlur: CGFloat, bassOpacity: Double) -> some View {
                    ZStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.purple.opacity(bassOpacity))
                                        .frame(width: 290, height: 290)
                                        .scaleEffect(bassScale)
                                        .blur(radius: bassBlur)
                                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])

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

                                    Circle()
                                        .fill(LinearGradient(
                                                                colors: [Color(white: 0.3), Color(white: 0.1)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 250, height: 250)
                                        .shadow(radius: 2)

                                    ZStack {
                                                        if let coverURL = track.localCoverURL, let uiImage = UIImage(contentsOfFile: coverURL.path) {
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

                                                                                Circle()
                                                                                    .fill(LinearGradient(
                                                                                                                    colors: [.purple, .cyan],
                                                                                                                    startPoint: .topLeading,
                                                                                                                    endPoint: .bottomTrailing
                                                                                    ))
                                                                                    .frame(width: 100, height: 100)

                                                                                Text(String(track.title.first ?? "M").uppercased())
                                                                                    .font(.system(size: 38, weight: .bold))
                                                                                    .foregroundColor(.white)
                                                                                    .shadow(radius: 2)
                                                        }

                                                        AngularGradient(
                                                                                gradient: Gradient(colors: [
                                                                                                            .clear, .white.opacity(0.12), .clear, .white.opacity(0.12), .clear
                                                                                ]),
                                                                                center: .center
                                                        )
                                                        .frame(width: 240, height: 240)
                                                        .clipShape(Circle())

                                                        ForEach(0..<15) { i in
                                                                                             Circle()
                                                                                                 .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                                                                                 .frame(width: CGFloat(40 + i * 13), height: CGFloat(40 + i * 13))
                                                                        }

                                                        Circle()
                                                            .fill(LinearGradient(
                                                                                        colors: [.white, .gray],
                                                                                        startPoint: .topLeading,
                                                                                        endPoint: .bottomTrailing
                                                            ))
                                                            .frame(width: 10, height: 10)
                                                            .shadow(radius: 1)

                                                        Circle()
                                                            .fill(Color.black)
                                                            .frame(width: 4, height: 4)
                                    }
                                    .rotationEffect(.degrees(rotationAngle))

                                    TonearmView(isPlaying: playerManager.playbackState == .playing)
                                        .offset(x: 95, y: -75)
                    }
                    .frame(width: 290, height: 290)
                    .contentShape(Rectangle())
                    .onTapGesture {
                                    cycleInterfaceMode()
                    }
        }
        private func coverArtView(for track: PlayerTrack, bassScale: CGFloat, bassBlur: CGFloat, bassCoverOpacity: Double) -> some View {
                    ZStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.purple.opacity(bassCoverOpacity))
                                        .frame(width: 280, height: 280)
                                        .scaleEffect(bassScale)
                                        .blur(radius: bassBlur)
                                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: visualizerEngine.heights[0])

                                    if let coverURL = track.localCoverURL, let uiImage = UIImage(contentsOfFile: coverURL.path) {
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
        }

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
        private func trackInfoView(for track: PlayerTrack) -> some View {
                    HStack(spacing: 0) {
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

                                                        Text("Source: \(track.sourceName)")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.gray)
                                                            .padding(.top, 4)
                                    }

                                    Spacer()

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
        }
        private var progressSliderView: some View {
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
        }

        private var controlPanelView: some View {
                    HStack(spacing: 28) {
                                    Button(action: {
                                                        HapticManager.shared.triggerImpact(style: .light)
                                                        playerManager.toggleShuffle()
                                    }) {
                                                        Image(systemName: "shuffle")
                                                            .font(.title3)
                                                            .foregroundColor(playerManager.isShuffleEnabled ? .cyan : .white.opacity(0.6))
                                    }
                                    .buttonStyle(ScaleButtonStyle())

                                    Button(action: {
                                                        HapticManager.shared.triggerImpact(style: .light)
                                                        playerManager.previousTrack()
                                    }) {
                                                        Image(systemName: "backward.fill")
                                                            .font(.title)
                                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(ScaleButtonStyle())

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

                                    Button(action: {
                                                        HapticManager.shared.triggerImpact(style: .light)
                                                        playerManager.nextTrack()
                                    }) {
                                                        Image(systemName: "forward.fill")
                                                            .font(.title)
                                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(ScaleButtonStyle())

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
        }
        private var volumeControlView: some View {
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
/// Движок спектральной визуализации с физикой пиков и реалистичным спектром
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
        
        // Энергосбережение: пропускаем пересчёт если музыка на паузе и полосы уже в нуле
        let allZero = heights.allSatisfy { $0 <= 0.035 } && peaks.allSatisfy { $0 <= 0.035 }
        if !isPlaying && allZero { return }
        
        time += 0.15
        
        for i in 0..<numberOfBars {
            var target: CGFloat = 0.03
            
            if isPlaying {
                let x = time + CGFloat(i) * 0.35
                if i < 6 {
                    // Басы: ритмичные всплески
                    let beat = abs(sin(time * 2.8))
                    let subBeat = abs(cos(time * 1.4)) * 0.3
                    let noise = CGFloat.random(in: -0.15...0.25)
                    let scale = CGFloat(6 - i) / 6.0
                    target = max((beat * 0.65 + subBeat + noise) * scale, 0.15)
                } else if i < 18 {
                    // Средние частоты
                    let wave1 = sin(x * 2.2) * 0.3
                    let wave2 = cos(x * 4.1) * 0.2
                    target = abs(wave1 + wave2) + CGFloat.random(in: 0.0...0.3) + 0.1
                } else {
                    // Высокие частоты
                    target = abs(sin(x * 6.5) * 0.15) + CGFloat.random(in: 0.0...0.4) + 0.05
                }
            }
            
            // Сглаживание
            let speed: CGFloat = isPlaying ? 0.28 : 0.12
            heights[i] = heights[i] + (target - heights[i]) * speed
            
            // Физика гравитации пиков
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

/// Спектрограф с физикой гравитации пиков
struct RealtimeVisualizerView: View {
    @ObservedObject var engine: VisualizerEngine
    let maxHeight: CGFloat = 80.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3.0) {
            ForEach(0..<engine.heights.count, id: \.self) { index in
                let barH = maxHeight * engine.heights[index]
                let peakH = maxHeight * engine.peaks[index]
                
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 5, height: maxHeight)
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 5, height: max(barH, 2))
                    
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Color.white)
                        .frame(width: 5, height: 1.5)
                        .offset(y: -peakH)
                }
                .frame(height: maxHeight)
            }
        }
    }
}
struct CircularVisualizerView: View {
        @ObservedObject var engine: VisualizerEngine
        var isPlaying: Bool

        var body: some View {
                    ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        .frame(width: 220, height: 220)

                                    ForEach(0..<36) { index in
                                                                     let angle = Double(index) * 10.0
                                                                     let heightIndex = index % engine.heights.count
                                                                     let barHeight = isPlaying ? engine.heights[heightIndex] * 0.8 : 5.0

                                                                     RoundedRectangle(cornerRadius: 2)
                                                                         .fill(LinearGradient(
                                                                                                     colors: [.purple, .cyan],
                                                                                                     startPoint: .bottom,
                                                                                                     endPoint: .top
                                                                         ))
                                                                         .frame(width: 3, height: barHeight)
                                                                         .offset(y: -110)
                                                                         .rotationEffect(.degrees(angle))
                                                    }
                    }
                    .frame(width: 250, height: 250)
        }
}

/// Реалистичный тонарм винилового проигрывателя
struct TonearmView: View {
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            // База тонарма
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
                
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.8), Color(white: 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 22, height: 22)
                
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 6, height: 6)
            }
            
            // Рычаг тонарма
            ZStack(alignment: .top) {
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
                
                // Картридж
                ZStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.orange)
                        .frame(width: 10, height: 20)
                        .shadow(radius: 1)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(white: 0.8), Color(white: 0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 12, height: 5)
                        .offset(y: -8)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 5, height: 1.2)
                        .offset(x: 7, y: 1)
                }
                .rotationEffect(.degrees(-32))
                .offset(x: -28, y: 130)
            }
            .frame(width: 30, height: 160)
            .offset(y: 80)
            .rotationEffect(.degrees(isPlaying ? 25 : -5), anchor: .top)
            .animation(.spring(response: 1.0, dampingFraction: 0.75, blendDuration: 0), value: isPlaying)
        }
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
        func makeUIView(context: Context) -> MPVolumeView {
                    let volumeView = MPVolumeView(frame: .zero)
                    volumeView.showsRouteButton = false

                    if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                                    slider.minimumTrackTintColor = .systemPurple
                                    slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
                                    slider.thumbTintColor = .white
                    }

                    return volumeView
        }

        func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

private struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
                    configuration.label
                        .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
        }
}
