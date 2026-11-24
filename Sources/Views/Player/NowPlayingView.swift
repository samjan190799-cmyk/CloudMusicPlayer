import SwiftUI
import MediaPlayer
import AVKit

/// Полноэкранный плеер. Фон и акценты берут цвет из обложки текущего трека.
/// Свайп вниз — свернуть, свайп по обложке влево/вправо — переключить трек.
struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var artwork = NowPlayingArtwork.shared
    @ObservedObject private var playlists = PlaylistManager.shared
    @AppStorage("dynamicPlayerColor") private var dynamicColor = true
    @Environment(\.accent) private var accent

    @State private var dragOffset: CGFloat = 0
    @State private var artworkOffset: CGFloat = 0
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var showQueue = false

    private var tint: Color {
        dynamicColor ? artwork.color : accent
    }

    var body: some View {
        ZStack {
            backgroundLayer

            GeometryReader { proxy in
                if let track = player.currentTrack {
                    content(track: track, size: proxy.size)
                }
            }
        }
        .offset(y: dragOffset)
        .gesture(dismissGesture)
        .sheet(isPresented: $showQueue) {
            QueueView()
                .themed()
        }
    }

    // MARK: - Фон

    private var backgroundLayer: some View {
        ZStack {
            Palette.background

            if let image = artwork.image, artwork.trackID == player.currentTrack?.id {
                Color.clear
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 80)
                            .scaleEffect(1.3)
                            .opacity(0.55)
                    )
                    .clipped()
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [tint.opacity(0.85), tint.opacity(0.45), Palette.background.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.9)

            Color.black.opacity(0.22)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: tint)
    }

    // MARK: - Контент

    private func content(track: PlayerTrack, size: CGSize) -> some View {
        let display = track.display
        let artworkSide = max(min(size.width - 56, size.height * 0.44), 160)

        return VStack(spacing: 0) {
            header(for: track)
                .padding(.top, 6)

            Spacer(minLength: 12)

            artworkView(for: track, side: artworkSide)

            Spacer(minLength: 16)

            VStack(spacing: 22) {
                titleRow(track: track, display: display)
                scrubber
                transportControls
                volumeRow
                bottomActions
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Шапка

    private func header(for track: PlayerTrack) -> some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 38, height: 5)

            HStack {
                CircleIconButton(systemName: "chevron.down", size: 38, iconSize: 15, background: Color.white.opacity(0.12)) {
                    AppRouter.shared.collapsePlayer()
                }
                .accessibilityLabel("Свернуть плеер")

                Spacer()

                VStack(spacing: 1) {
                    Text("СЕЙЧАС ИГРАЕТ")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color.white.opacity(0.6))
                    Text(sourceTitle(for: track))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    moreMenu(for: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .accessibilityLabel("Ещё")
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func moreMenu(for track: PlayerTrack) -> some View {
        let isFavorite = playlists.isTrackFavorite(trackId: track.id)

        Button {
            playlists.toggleFavorite(track: track.toPlaylistTrack())
        } label: {
            Label(isFavorite ? "Убрать из избранного" : "В избранное", systemImage: isFavorite ? "heart.slash" : "heart")
        }

        Button {
            AppRouter.shared.addToPlaylist(track.toPlaylistTrack())
        } label: {
            Label("Добавить в плейлист", systemImage: "text.badge.plus")
        }

        if TrackActions.canDownload(track) {
            Button {
                _ = TrackActions.download(track)
            } label: {
                Label("Скачать", systemImage: "arrow.down.circle")
            }
        }

        Button {
            showQueue = true
        } label: {
            Label("Очередь", systemImage: "list.bullet")
        }
    }

    private func sourceTitle(for track: PlayerTrack) -> String {
        let name = track.sourceName
        if name.contains("YouTube") { return "YouTube" }
        if name.contains("Google") { return "Google Диск" }
        if name.contains("Яндекс") { return "Яндекс Диск" }
        if name.contains("Telegram") { return "Telegram" }
        if name == "Аудиокниги" { return "Аудиокнига" }
        return name.isEmpty ? "Медиатека" : name
    }

    // MARK: Обложка

    private func artworkView(for track: PlayerTrack, side: CGFloat) -> some View {
        let isActive = player.playbackState == .playing || player.playbackState == .loading

        return NowPlayingArtworkView(track: track, cornerRadius: 16)
            .frame(width: side, height: side)
            .shadow(color: Color.black.opacity(isActive ? 0.5 : 0.3), radius: isActive ? 34 : 18, x: 0, y: isActive ? 20 : 10)
            .scaleEffect(isActive ? 1.0 : 0.84)
            .animation(.spring(response: 0.55, dampingFraction: 0.68), value: isActive)
            .offset(x: artworkOffset)
            .rotationEffect(.degrees(Double(artworkOffset) / 40))
            .gesture(artworkGesture)
            .onTapGesture(count: 2) {
                playlists.toggleFavorite(track: track.toPlaylistTrack())
                HapticManager.shared.triggerNotification(type: .success)
            }
            .accessibilityLabel("Обложка. Смахните, чтобы переключить трек")
    }

    // MARK: Название и избранное

    private func titleRow(track: PlayerTrack, display: TrackText.Display) -> some View {
        let isFavorite = playlists.isTrackFavorite(trackId: track.id)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(display.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(display.artist)
                    .font(.system(size: 17))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(track.id)

            Button {
                HapticManager.shared.triggerImpact(style: .medium)
                playlists.toggleFavorite(track: track.toPlaylistTrack())
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isFavorite ? accent : .white)
                    .scaleEffect(isFavorite ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFavorite)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.85))
            .accessibilityLabel(isFavorite ? "Убрать из избранного" : "В избранное")
        }
    }

    // MARK: Прогресс

    private var scrubber: some View {
        let duration = max(player.duration, 0)
        let value = isScrubbing ? scrubValue : player.currentTime

        return VStack(spacing: 6) {
            GeometryReader { proxy in
                let fraction = duration > 0 ? CGFloat(min(max(value / duration, 0), 1)) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(proxy.size.width * fraction, isScrubbing ? 8 : 4))
                }
                .frame(height: isScrubbing ? 9 : 5)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard duration > 0 else { return }
                            if !isScrubbing {
                                HapticManager.shared.triggerSelection()
                            }
                            withAnimation(.easeOut(duration: 0.12)) {
                                isScrubbing = true
                            }
                            let ratio = min(max(gesture.location.x / proxy.size.width, 0), 1)
                            scrubValue = Double(ratio) * duration
                        }
                        .onEnded { _ in
                            guard duration > 0 else { return }
                            player.seek(to: scrubValue)
                            withAnimation(.easeOut(duration: 0.2)) {
                                isScrubbing = false
                            }
                        }
                )
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.15), value: isScrubbing)

            HStack {
                Text(Formatters.time(value))
                Spacer()
                if player.isBuffering || player.playbackState == .loading {
                    Text("Загрузка…")
                }
                Spacer()
                Text("-" + Formatters.time(max(duration - value, 0)))
            }
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundColor(Color.white.opacity(isScrubbing ? 0.95 : 0.6))
        }
    }

    // MARK: Кнопки управления

    private var transportControls: some View {
        HStack {
            Button {
                HapticManager.shared.triggerSelection()
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.isShuffleEnabled ? accent : Color.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(player.isShuffleEnabled ? "Перемешивание включено" : "Перемешивание выключено")

            Spacer()

            Button {
                HapticManager.shared.triggerImpact(style: .light)
                player.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.85))
            .accessibilityLabel("Предыдущий трек")

            Spacer()

            Button {
                HapticManager.shared.triggerImpact(style: .medium)
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                    if player.playbackState == .loading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: player.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.black)
                            .offset(x: player.playbackState == .playing ? 0 : 2)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.9))
            .accessibilityLabel(player.playbackState == .playing ? "Пауза" : "Воспроизвести")

            Spacer()

            Button {
                HapticManager.shared.triggerImpact(style: .light)
                player.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.85))
            .accessibilityLabel("Следующий трек")

            Spacer()

            Button {
                HapticManager.shared.triggerSelection()
                player.toggleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.repeatMode == .none ? Color.white.opacity(0.7) : accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(repeatLabel)
        }
    }

    private var repeatLabel: String {
        switch player.repeatMode {
        case .none: return "Повтор выключен"
        case .all: return "Повтор очереди"
        case .one: return "Повтор трека"
        }
    }

    // MARK: Громкость

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12))
            SystemVolumeSlider()
                .frame(height: 30)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
        }
        .foregroundColor(Color.white.opacity(0.6))
    }

    // MARK: Нижние действия

    private var bottomActions: some View {
        HStack {
            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button {
                        player.setPlaybackRate(Float(rate))
                    } label: {
                        if abs(Double(player.playbackRate) - rate) < 0.01 {
                            Label(rateTitle(rate), systemImage: "checkmark")
                        } else {
                            Text(rateTitle(rate))
                        }
                    }
                }
            } label: {
                Text(rateTitle(Double(player.playbackRate)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(player.playbackRate == 1.0 ? Color.white.opacity(0.75) : accent)
                    .frame(width: 52, height: 40)
            }
            .accessibilityLabel("Скорость воспроизведения")

            Spacer()

            Menu {
                ForEach([5, 15, 30, 45, 60], id: \.self) { minutes in
                    Button("\(minutes) мин") {
                        player.setSleepTimer(minutes: minutes)
                        AppRouter.shared.showToast("Таймер сна: \(minutes) мин", icon: "moon.fill")
                    }
                }
                if player.sleepTimerTimeRemaining != nil {
                    Divider()
                    Button("Выключить таймер", role: .destructive) {
                        player.setSleepTimer(minutes: 0)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: player.sleepTimerTimeRemaining == nil ? "moon" : "moon.fill")
                        .font(.system(size: 18))
                    if let remaining = player.sleepTimerTimeRemaining {
                        Text(Formatters.time(remaining))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                .foregroundColor(player.sleepTimerTimeRemaining == nil ? Color.white.opacity(0.75) : accent)
                .frame(minWidth: 52, minHeight: 40)
            }
            .accessibilityLabel("Таймер сна")

            Spacer()

            AirPlayButton()
                .frame(width: 52, height: 40)
                .accessibilityLabel("AirPlay")

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .frame(width: 52, height: 40)
            }
            .accessibilityLabel("Очередь")
        }
    }

    private func rateTitle(_ rate: Double) -> String {
        var text = String(format: "%.2f", rate)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text + "×"
    }

    // MARK: - Жесты

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dy = value.translation.height
                if dy > 0 && abs(dy) > abs(value.translation.width) {
                    dragOffset = dy
                }
            }
            .onEnded { value in
                finishVerticalDrag(value)
            }
    }

    private var artworkGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    artworkOffset = dx * 0.6
                } else if dy > 0 {
                    dragOffset = dy
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    if abs(dx) > 90 {
                        HapticManager.shared.triggerImpact(style: .light)
                        if dx < 0 {
                            player.nextTrack()
                        } else {
                            player.previousTrack()
                        }
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        artworkOffset = 0
                    }
                } else {
                    finishVerticalDrag(value)
                }
            }
    }

    private func finishVerticalDrag(_ value: DragGesture.Value) {
        let shouldDismiss = value.translation.height > 150 || value.predictedEndTranslation.height > 380
        if shouldDismiss {
            AppRouter.shared.collapsePlayer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                dragOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                dragOffset = 0
            }
        }
    }
}

// MARK: - Системная громкость (MPVolumeView)

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        view.setVolumeThumbImage(Self.thumbImage(), for: .normal)
        styleSlider(in: view)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        styleSlider(in: uiView)
    }

    private func styleSlider(in view: MPVolumeView) {
        guard let slider = view.subviews.compactMap({ $0 as? UISlider }).first else { return }
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.22)
    }

    private static func thumbImage() -> UIImage {
        let size = CGSize(width: 14, height: 14)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Кнопка AirPlay

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor.white.withAlphaComponent(0.75)
        picker.activeTintColor = .white
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
