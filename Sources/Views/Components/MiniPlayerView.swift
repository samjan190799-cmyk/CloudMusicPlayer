import SwiftUI

/// Вспомогательное представление мини-плеера внизу экрана
struct MiniPlayerView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Binding var isPlayerExpanded: Bool
    
    var body: some View {
        guard let track = playerManager.currentTrack else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Иконка/обложка
                    ZStack(alignment: .bottomTrailing) {
                        if let coverURL = track.localCoverURL,
                           let uiImage = UIImage(contentsOfFile: coverURL.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Полупрозрачный оверлей с микро-визуализатором в правом нижнем углу
                            if playerManager.playbackState == .playing {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 20, height: 18)
                                    
                                    MiniVisualizerView(isPlaying: true)
                                }
                                .padding(2)
                                .transition(.opacity)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                            
                            if playerManager.playbackState == .playing {
                                MiniVisualizerView(isPlaying: true, tintColor: .white)
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                        }
                    }
                    
                    // Название трека и источник
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(track.sourceName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Кнопки управления
                    HStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            playerManager.togglePlayPause()
                        }) {
                            Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(width: 32, height: 32)
                        .buttonStyle(ScaleButtonStyle())
                        
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(width: 32, height: 32)
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Тонкий индикатор прогресса трека
                GeometryReader { geo in
                    let percent = playerManager.duration > 0 ? CGFloat(playerManager.currentTime / playerManager.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * min(max(percent, 0.0), 1.0), height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            )
            .shadow(color: Color.purple.opacity(0.12), radius: 10, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 4)
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isPlayerExpanded = true
                }
            }
        )
    }
}

/// Анимация масштабирования кнопок при нажатии
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
