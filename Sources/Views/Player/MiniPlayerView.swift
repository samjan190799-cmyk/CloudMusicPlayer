import SwiftUI

/// Плавающий мини-плеер над таб-баром.
/// Тап — открыть плеер, свайп вверх — тоже, свайп влево/вправо — следующий/предыдущий трек.
struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject private var artwork = NowPlayingArtwork.shared
    @AppStorage("dynamicPlayerColor") private var dynamicColor = true
    @Environment(\.accent) private var accent

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if let track = player.currentTrack {
            content(for: track)
        }
    }

    private var tint: Color {
        dynamicColor ? artwork.color : accent
    }

    private var progress: CGFloat {
        guard player.duration > 0 else { return 0 }
        return CGFloat(min(max(player.currentTime / player.duration, 0), 1))
    }

    private func content(for track: PlayerTrack) -> some View {
        let display = track.display

        return HStack(spacing: 12) {
            NowPlayingArtworkView(track: track, cornerRadius: 8)
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(display.artist)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .id(track.id)
            .transition(.opacity)

            Spacer(minLength: 4)

            playPauseButton

            Button {
                HapticManager.shared.triggerImpact(style: .light)
                player.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.85))
            .accessibilityLabel("Следующий трек")
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(height: 60)
        .background(background)
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: proxy.size.width * progress, height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, 14)
            .padding(.bottom, 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
        .offset(x: dragOffset)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            AppRouter.shared.expandPlayer()
        }
        .gesture(swipeGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Сейчас играет: \(display.title), \(display.artist)")
    }

    private var background: some View {
        ZStack {
            Palette.backgroundRaised
            LinearGradient(
                colors: [tint.opacity(0.75), tint.opacity(0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
            Color.black.opacity(0.18)
        }
        .animation(.easeInOut(duration: 0.5), value: tint)
    }

    private var playPauseButton: some View {
        Button {
            HapticManager.shared.triggerImpact(style: .medium)
            player.togglePlayPause()
        } label: {
            ZStack {
                if player.playbackState == .loading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: player.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 40, height: 44)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.85))
        .accessibilityLabel(player.playbackState == .playing ? "Пауза" : "Воспроизвести")
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let horizontal = value.translation.width
                if abs(horizontal) > abs(value.translation.height) {
                    dragOffset = horizontal * 0.55
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) && abs(dx) > 70 {
                    HapticManager.shared.triggerImpact(style: .light)
                    if dx < 0 {
                        player.nextTrack()
                    } else {
                        player.previousTrack()
                    }
                } else if dy < -30 {
                    AppRouter.shared.expandPlayer()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    dragOffset = 0
                }
            }
    }
}
