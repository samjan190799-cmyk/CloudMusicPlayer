import SwiftUI

/// Мини-плеер: стекло с оттенком обложки, свайп влево/вправо — смена трека, свайп вверх или тап — открыть плеер
struct MiniPlayerView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Binding var isPlayerExpanded: Bool

    @StateObject private var artwork = NowPlayingArtworkLoader()
    @State private var swipeOffset: CGFloat = 0

    private var isPlaying: Bool { playerManager.playbackState == .playing }

    var body: some View {
        Group {
            if let track = playerManager.currentTrack {
                content(for: track)
            }
        }
        .onAppear { artwork.load(for: playerManager.currentTrack) }
        .onChange(of: playerManager.currentTrack) { newTrack in
            artwork.load(for: newTrack)
        }
    }

    private func content(for track: PlayerTrack) -> some View {
        HStack(spacing: 12) {
            ZStack {
                ArtworkImageView(image: artwork.image, title: track.title, cornerRadius: 10)
                    .frame(width: 46, height: 46)
                    .shadow(color: artwork.tint.opacity(0.4), radius: 8, x: 0, y: 3)

                if isPlaying {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 24, height: 22)
                    MiniVisualizerView(isPlaying: true, tintColor: .white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: swipeOffset * 0.35)
            .opacity(1 - Double(min(abs(swipeOffset) / 220, 0.6)))

            HStack(spacing: 4) {
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    if playerManager.playbackState != .loading {
                        playerManager.togglePlayPause()
                    }
                }) {
                    ZStack {
                        if playerManager.playbackState == .loading || playerManager.isBuffering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .transition(.scale.combined(with: .opacity))
                                .id(isPlaying)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                }
                .buttonStyle(SpringScaleButtonStyle(scale: 0.85))
                .accessibilityLabel(isPlaying ? "Пауза" : "Воспроизвести")

                Button(action: {
                    HapticManager.shared.triggerImpact(style: .light)
                    playerManager.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                }
                .buttonStyle(SpringScaleButtonStyle(scale: 0.85))
                .accessibilityLabel("Следующий трек")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [artwork.tint.opacity(0.28), artwork.tint.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(alignment: .bottom) {
            progressLine
                .padding(.horizontal, 14)
        }
        .liquidGlass(cornerRadius: 20, opacity: 0.65)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            expand()
        }
        .gesture(swipeGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Открыть плеер") { expand() }
    }

    private var progressLine: some View {
        GeometryReader { geo in
            let percent = playerManager.duration > 0
                ? CGFloat(playerManager.currentTime / playerManager.duration)
                : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color.white)
                    .frame(width: geo.size.width * min(max(percent, 0), 1))
            }
        }
        .frame(height: 2)
        .padding(.bottom, 1)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    swipeOffset = value.translation.width
                }
            }
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                if abs(height) > abs(width), height < -30 {
                    expand()
                } else if width < -70 {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playerManager.nextTrack()
                } else if width > 70 {
                    HapticManager.shared.triggerImpact(style: .medium)
                    playerManager.previousTrack()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    swipeOffset = 0
                }
            }
    }

    private func expand() {
        HapticManager.shared.triggerImpact(style: .light)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            isPlayerExpanded = true
        }
    }
}
