import SwiftUI
import MediaPlayer
import AVKit

/// Полноэкранный плеер: адаптивный фон по обложке, жесты (свайп вниз — свернуть,
/// свайп по обложке — сменить трек), крупный скраббер, очередь и системный AirPlay.
struct PlayerDetailView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var isPlayerExpanded: Bool

    @AppStorage("playerInterfaceMode") private var playerInterfaceMode = "cover"

    @StateObject private var artwork = NowPlayingArtworkLoader()
    /// Движок визуализации хранится в холдере без @Published, чтобы 30 fps обновления
    /// перерисовывали только подвиды спектрографа, а не весь экран
    @StateObject private var visuals = VisualizerHolder()

    @State private var dismissOffset: CGFloat = 0
    @State private var artworkSwipe: CGFloat = 0
    @State private var showQueue = false
    @State private var showAddToPlaylist = false

    private var isPlaying: Bool { playerManager.playbackState == .playing }

    var body: some View {
        Group {
            if let track = playerManager.currentTrack {
                GeometryReader { geo in
                    ZStack {
                        AdaptiveArtworkBackground(image: artwork.image, tint: artwork.tint)

                        BassReactiveGlow(engine: visuals.engine, tint: artwork.tint, isPlaying: isPlaying)
                            .offset(y: -geo.size.height * 0.18)
                            .allowsHitTesting(false)

                        VStack(spacing: 0) {
                            headerView(for: track)
                                .padding(.top, 6)

                            Spacer(minLength: 12)

                            stageView(for: track, side: stageSide(in: geo.size))

                            Spacer(minLength: 12)

                            trackInfoView(for: track)
                                .padding(.bottom, 18)

                            PlayerScrubber(
                                current: playerManager.currentTime,
                                duration: playerManager.duration,
                                onSeek: { playerManager.seek(to: $0) }
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)

                            transportControls(for: track)
                                .padding(.bottom, 18)

                            volumeControlView
                                .padding(.bottom, 14)

                            bottomToolbar
                                .padding(.bottom, 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .offset(y: dismissOffset)
                    .gesture(dismissGesture)
                }
                .sheet(isPresented: $showQueue) {
                    QueueSheetView()
                }
                .sheet(isPresented: $showAddToPlaylist) {
                    AddToPlaylistView(track: track.toPlaylistTrack())
                }
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { artwork.load(for: playerManager.currentTrack) }
        .onChange(of: playerManager.currentTrack) { newTrack in
            artwork.load(for: newTrack)
        }
    }

    private func stageSide(in size: CGSize) -> CGFloat {
        min(size.width - 48, size.height * 0.40)
    }

    // MARK: - Жест сворачивания

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard value.translation.height > 0,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 140 || value.predictedEndTranslation.height > 320
                if shouldDismiss {
                    HapticManager.shared.triggerImpact(style: .light)
                    close()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dismissOffset = 0
                    }
                }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isPlayerExpanded = false
        }
    }

    // MARK: - Хедер

    private func headerView(for track: PlayerTrack) -> some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 38, height: 5)

            HStack {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .light)
                    close()
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(SpringScaleButtonStyle(scale: 0.88))
                .accessibilityLabel("Свернуть плеер")

                Spacer()

                VStack(spacing: 2) {
                    Text("ИГРАЕТ ИЗ")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.5))
                    Text(track.sourceName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    Picker("Вид", selection: interfaceModeBinding) {
                        Label("Обложка", systemImage: "square.fill").tag("cover")
                        Label("Винил", systemImage: "record.circle").tag("vinyl")
                        Label("Спектр", systemImage: "waveform").tag("visualizer")
                    }
                    Divider()
                    Button {
                        showAddToPlaylist = true
                    } label: {
                        Label("Добавить в плейлист", systemImage: "text.badge.plus")
                    }
                    Button {
                        showQueue = true
                    } label: {
                        Label("Очередь воспроизведения", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .accessibilityLabel("Ещё")
            }
        }
        .padding(.horizontal, 20)
    }

    private var interfaceModeBinding: Binding<String> {
        Binding(
            get: { playerInterfaceMode },
            set: { newValue in
                HapticManager.shared.triggerImpact(style: .medium)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    playerInterfaceMode = newValue
                }
            }
        )
    }

    // MARK: - Сцена (обложка / винил / спектр)

    @ViewBuilder
    private func stageView(for track: PlayerTrack, side: CGFloat) -> some View {
        ZStack {
            switch playerInterfaceMode {
            case "vinyl":
                VinylStageView(
                    image: artwork.image,
                    title: track.title,
                    isPlaying: isPlaying
                )
                .scaleEffect(side / 290)
                .frame(width: side, height: side)
            case "visualizer":
                VStack(spacing: 12) {
                    RealtimeVisualizerView(engine: visuals.engine)
                        .frame(height: 100)
                    CircularVisualizerView(engine: visuals.engine, isPlaying: isPlaying)
                }
                .frame(width: 290, height: 290)
                .scaleEffect(side / 290)
                .frame(width: side, height: side)
            default:
                ArtworkImageView(image: artwork.image, title: track.title, cornerRadius: 22)
                    .frame(width: side, height: side)
                    .shadow(color: artwork.tint.opacity(isPlaying ? 0.45 : 0.2), radius: 40, x: 0, y: 18)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 12)
                    .scaleEffect(isPlaying ? 1.0 : 0.84)
                    .animation(.spring(response: 0.55, dampingFraction: 0.72), value: isPlaying)
            }
        }
        .frame(width: side, height: side)
        .offset(x: artworkSwipe)
        .rotation3DEffect(.degrees(Double(artworkSwipe) / 14), axis: (x: 0, y: 1, z: 0))
        .opacity(1 - Double(min(abs(artworkSwipe) / 400, 0.5)))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            HapticManager.shared.triggerImpact(style: .medium)
            playlistManager.toggleFavorite(track: track.toPlaylistTrack())
        }
        .gesture(artworkSwipeGesture)
        .transition(.opacity)
        .id(playerInterfaceMode)
    }

    private var artworkSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    artworkSwipe = value.translation.width
                } else if value.translation.height > 0 {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { value in
                if dismissOffset > 0 {
                    if value.translation.height > 140 || value.predictedEndTranslation.height > 320 {
                        HapticManager.shared.triggerImpact(style: .light)
                        close()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dismissOffset = 0 }
                    }
                    return
                }

                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if width < -90 || predicted < -260 {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playerManager.nextTrack()
                } else if width > 90 || predicted > 260 {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playerManager.previousTrack()
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    artworkSwipe = 0
                }
            }
    }

    // MARK: - Информация о треке

    private func trackInfoView(for track: PlayerTrack) -> some View {
        let isFavorite = playlistManager.isTrackFavorite(trackId: track.id)

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.25), value: track.id)

            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                playlistManager.toggleFavorite(track: track.toPlaylistTrack())
            }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isFavorite ? .white : .white.opacity(0.7))
                    .scaleEffect(isFavorite ? 1.08 : 1.0)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(isFavorite ? 0.18 : 0.08)))
            }
            .buttonStyle(SpringScaleButtonStyle(scale: 0.85))
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isFavorite)
            .accessibilityLabel(isFavorite ? "Убрать из избранного" : "Добавить в избранное")
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Кнопки управления

    /// Для аудиокниг и длинных записей боковые кнопки становятся перемоткой −15 / +30 с
    private func isLongForm(_ track: PlayerTrack) -> Bool {
        track.sourceName == "Аудиокниги" || playerManager.duration > 20 * 60
    }

    private func transportControls(for track: PlayerTrack) -> some View {
        let longForm = isLongForm(track)

        return HStack(spacing: 0) {
            if longForm {
                sideButton(icon: "gobackward.15", isActive: false, label: "Назад на 15 секунд") {
                    playerManager.skipBackward15()
                }
            } else {
                sideButton(icon: "shuffle", isActive: playerManager.isShuffleEnabled, label: "Перемешать") {
                    playerManager.toggleShuffle()
                }
            }

            Spacer()

            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(TransportButtonStyle(diameter: 62))
            .accessibilityLabel("Предыдущий трек")

            Spacer()

            Button(action: {
                HapticManager.shared.triggerImpact(style: .medium)
                if playerManager.playbackState != .loading {
                    playerManager.togglePlayPause()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                        .shadow(color: artwork.tint.opacity(0.55), radius: 22, x: 0, y: 6)

                    if playerManager.playbackState == .loading || playerManager.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: isPlaying ? 0 : 3)
                            .transition(.scale.combined(with: .opacity))
                            .id(isPlaying)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
            }
            .buttonStyle(SpringScaleButtonStyle(scale: 0.9))
            .accessibilityLabel(isPlaying ? "Пауза" : "Воспроизвести")

            Spacer()

            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(TransportButtonStyle(diameter: 62))
            .accessibilityLabel("Следующий трек")

            Spacer()

            if longForm {
                sideButton(icon: "goforward.30", isActive: false, label: "Вперёд на 30 секунд") {
                    playerManager.skipForward30()
                }
            } else {
                sideButton(
                    icon: playerManager.repeatMode == .one ? "repeat.1" : "repeat",
                    isActive: playerManager.repeatMode != .none,
                    label: "Повтор"
                ) {
                    playerManager.toggleRepeatMode()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func sideButton(icon: String, isActive: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.triggerImpact(style: .light)
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isActive ? .white : .white.opacity(0.55))
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(isActive ? 1 : 0)
            }
        }
        .buttonStyle(TransportButtonStyle(diameter: 44))
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Громкость

    private var volumeControlView: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.triggerImpact(style: .light)
                playerManager.isMuted.toggle()
            }) {
                Image(systemName: playerManager.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22)
            }
            .accessibilityLabel(playerManager.isMuted ? "Включить звук" : "Выключить звук")

            SystemVolumeSlider()
                .frame(height: 30)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 22)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Нижняя панель: скорость, таймер сна, AirPlay, очередь

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0] as [Float], id: \.self) { rate in
                    Button {
                        HapticManager.shared.triggerSelection()
                        playerManager.setPlaybackRate(rate)
                    } label: {
                        if playerManager.playbackRate == rate {
                            Label(formatRate(rate), systemImage: "checkmark")
                        } else {
                            Text(formatRate(rate))
                        }
                    }
                }
            } label: {
                toolbarItem(
                    content: AnyView(
                        Text(formatRate(playerManager.playbackRate))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    ),
                    caption: "Скорость",
                    isActive: playerManager.playbackRate != 1.0
                )
            }
            .accessibilityLabel("Скорость воспроизведения")

            Menu {
                if playerManager.sleepTimerTimeRemaining != nil {
                    Button(role: .destructive) {
                        playerManager.setSleepTimer(minutes: 0)
                    } label: {
                        Label("Выключить таймер", systemImage: "xmark")
                    }
                }
                ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                    Button("\(minutes) минут") {
                        HapticManager.shared.triggerSelection()
                        playerManager.setSleepTimer(minutes: minutes)
                    }
                }
            } label: {
                toolbarItem(
                    content: AnyView(
                        Group {
                            if let remaining = playerManager.sleepTimerTimeRemaining {
                                Text(formatTime(remaining))
                                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            } else {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                    ),
                    caption: "Таймер",
                    isActive: playerManager.sleepTimerTimeRemaining != nil
                )
            }
            .accessibilityLabel("Таймер сна")

            VStack(spacing: 4) {
                AirPlayRoutePicker()
                    .frame(width: 28, height: 24)
                Text("Вывод")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Устройство вывода звука")

            Button {
                HapticManager.shared.triggerImpact(style: .light)
                showQueue = true
            } label: {
                toolbarItem(
                    content: AnyView(
                        Image(systemName: "list.bullet")
                            .font(.system(size: 17, weight: .semibold))
                    ),
                    caption: "Очередь",
                    isActive: false
                )
            }
            .buttonStyle(SpringScaleButtonStyle(scale: 0.9))
            .accessibilityLabel("Очередь воспроизведения")
        }
        .padding(.horizontal, 16)
    }

    private func toolbarItem(content: AnyView, caption: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            content
                .foregroundColor(isActive ? .white : .white.opacity(0.7))
                .frame(height: 24)
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func formatRate(_ rate: Float) -> String {
        var text = String(format: "%.2f", rate)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text + "×"
    }

    private func formatTime(_ time: Double) -> String {
        PlayerTimeFormatter.string(from: time)
    }
}

// MARK: - Форматирование времени

enum PlayerTimeFormatter {
    static func string(from time: Double) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Скраббер прогресса

/// Прогресс-бар, который утолщается при перетаскивании и показывает оставшееся время
struct PlayerScrubber: View {
    let current: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var dragValue: Double? = nil

    var body: some View {
        let total = max(duration, 1)
        let shown = dragValue ?? current
        let fraction = CGFloat(min(max(shown / total, 0), 1))
        let isActive = dragValue != nil

        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                    Rectangle()
                        .fill(Color.white.opacity(isActive ? 1.0 : 0.85))
                        .frame(width: geo.size.width * fraction)
                }
                .frame(height: isActive ? 12 : 6)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(isActive ? 0.25 : 0), radius: 8)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragValue == nil {
                                HapticManager.shared.triggerImpact(style: .light)
                            }
                            let percentage = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                            dragValue = Double(percentage) * total
                        }
                        .onEnded { _ in
                            if let value = dragValue {
                                onSeek(value)
                            }
                            dragValue = nil
                        }
                )
            }
            .frame(height: 24)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)

            HStack {
                Text(PlayerTimeFormatter.string(from: shown))
                Spacer()
                Text(duration > 0 ? "−" + PlayerTimeFormatter.string(from: max(total - shown, 0)) : "--:--")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundColor(.white.opacity(isActive ? 0.9 : 0.5))
        }
        .accessibilityElement()
        .accessibilityLabel("Позиция воспроизведения")
        .accessibilityValue("\(PlayerTimeFormatter.string(from: shown)) из \(PlayerTimeFormatter.string(from: duration))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSeek(min(current + 15, duration))
            case .decrement: onSeek(max(current - 15, 0))
            @unknown default: break
            }
        }
    }
}

// MARK: - Стиль кнопок транспорта (подсветка круга при нажатии)

private struct TransportButtonStyle: ButtonStyle {
    var diameter: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: diameter, height: diameter)
            .background(
                Circle().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0))
            )
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Винил

/// Виниловая пластинка с плавным вращением и тонармом (базовый размер 290×290)
private struct VinylStageView: View {
    let image: UIImage?
    let title: String
    let isPlaying: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [Color(white: 0.08), Color(white: 0.2), Color(white: 0.06), Color(white: 0.18), Color(white: 0.08)],
                            center: .center
                        )
                    )
                    .frame(width: 250, height: 250)
                    .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 6)

                ForEach(0..<12) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.6)
                        .frame(width: CGFloat(110 + i * 11), height: CGFloat(110 + i * 11))
                }

                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.14)
                        Text(String(title.first ?? "M").uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())

                Circle()
                    .fill(LinearGradient(colors: [.white, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
            }
            .modifier(SpinningModifier(isPlaying: isPlaying))

            // Блик на пластинке остаётся неподвижным — добавляет объём
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), .clear, Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .allowsHitTesting(false)

            TonearmView(isPlaying: isPlaying)
                .offset(x: 95, y: -75)
        }
        .frame(width: 290, height: 290)
    }
}

/// Плавное вращение на базе TimelineView (без таймера, перерисовывающего весь экран)
private struct SpinningModifier: ViewModifier {
    let isPlaying: Bool
    var degreesPerSecond: Double = 18

    @State private var baseAngle: Double = 0
    @State private var startDate: Date? = nil

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isPlaying)) { context in
            content.rotationEffect(.degrees(angle(at: context.date)))
        }
        .onAppear {
            if isPlaying { startDate = Date() }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startDate = Date()
            } else if let start = startDate {
                baseAngle += Date().timeIntervalSince(start) * degreesPerSecond
                startDate = nil
            }
        }
    }

    private func angle(at date: Date) -> Double {
        guard let start = startDate else { return baseAngle }
        return baseAngle + date.timeIntervalSince(start) * degreesPerSecond
    }
}

// MARK: - Свечение в такт басу

private final class VisualizerHolder: ObservableObject {
    let engine = VisualizerEngine()
}

private struct BassReactiveGlow: View {
    @ObservedObject var engine: VisualizerEngine
    let tint: Color
    let isPlaying: Bool

    var body: some View {
        let bass = isPlaying ? engine.heights[0] : 0.05

        Circle()
            .fill(tint.opacity(0.16 + Double(bass) * 0.22))
            .frame(width: 340, height: 340)
            .scaleEffect(1.0 + bass * 0.12)
            .blur(radius: 90)
    }
}

// MARK: - Очередь воспроизведения

struct QueueSheetView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(playerManager.playlist.enumerated()), id: \.offset) { index, track in
                        let isCurrent = track.id == playerManager.currentTrack?.id

                        Button {
                            HapticManager.shared.triggerImpact(style: .light)
                            if !isCurrent {
                                playerManager.play(track: track, in: playerManager.playlist)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                QueueArtwork(track: track)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.title)
                                        .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isCurrent {
                                    MiniVisualizerView(
                                        isPlaying: playerManager.playbackState == .playing,
                                        tintColor: .white
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(isCurrent ? Color.white.opacity(0.10) : Color.clear)
                        .id(index)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear {
                    if let index = playerManager.playlist.firstIndex(where: { $0.id == playerManager.currentTrack?.id }) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Очередь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .overlay {
                if playerManager.playlist.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                        Text("Очередь пуста")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

private struct QueueArtwork: View {
    let track: PlayerTrack

    var body: some View {
        Group {
            if let coverURL = track.localCoverURL, let uiImage = UIImage(contentsOfFile: coverURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if track.sourceName.contains("YouTube") || track.sourceName == "Аудиокниги" {
                RemoteCoverLoader(
                    trackId: track.id,
                    sourceName: track.sourceName,
                    width: 44,
                    height: 44,
                    cornerRadius: 8
                )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
    }
}

// MARK: - AirPlay

struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor.white.withAlphaComponent(0.7)
        view.activeTintColor = .white
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Системный VolumeSlider

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView()
        volumeView.showsRouteButton = false // AirPlay вынесен в нижнюю панель

        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 14, height: 14)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 14, height: 14))
        }
        volumeView.setVolumeThumbImage(thumb, for: .normal)

        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.minimumTrackTintColor = .white
            slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
        }
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}


// MARK: - Вспомогательные классы и структуры визуализации

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
        
        let allZero = heights.allSatisfy { $0 <= 0.035 } && peaks.allSatisfy { $0 <= 0.035 }
        if !isPlaying && allZero { return }
        
        time += 0.15
        
        for i in 0..<numberOfBars {
            var target: CGFloat = 0.03
            
            if isPlaying {
                let x = time + CGFloat(i) * 0.35
                if i < 6 {
                    let beat = abs(sin(time * 2.8))
                    let subBeat = abs(cos(time * 1.4)) * 0.3
                    let noise = CGFloat.random(in: -0.15...0.25)
                    let scale = CGFloat(6 - i) / 6.0
                    target = max((beat * 0.65 + subBeat + noise) * scale, 0.15)
                } else if i < 18 {
                    let wave1 = sin(x * 2.2) * 0.3
                    let wave2 = cos(x * 4.1) * 0.2
                    target = abs(wave1 + wave2) + CGFloat.random(in: 0.0...0.3) + 0.1
                } else {
                    target = abs(sin(x * 6.5) * 0.15) + CGFloat.random(in: 0.0...0.4) + 0.05
                }
            }
            
            let speed: CGFloat = isPlaying ? 0.28 : 0.12
            heights[i] = heights[i] + (target - heights[i]) * speed
            
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
                            colors: [Color.white.opacity(0.90), Color.white.opacity(0.35)],
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
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.30)],
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

struct TonearmView: View {
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
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
                
                ZStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.22))
                        .frame(width: 10, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                        )
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
