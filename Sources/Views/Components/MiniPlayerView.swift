import SwiftUI

/// Вспомогательное представление мини-плеера в стиле Liquid Glass 2026
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
                    // Обложка трека с неоновым свечением
                    ZStack(alignment: .center) {
                        if let coverURL = track.localCoverURL,
                           let uiImage = UIImage(contentsOfFile: coverURL.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: AppTheme.neonCyan.opacity(0.2), radius: 6, x: 0, y: 3)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.primaryGradient)
                                .frame(width: 44, height: 44)
                                .shadow(color: AppTheme.neonPurple.opacity(0.3), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "music.note")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        if playerManager.playbackState == .playing {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.65))
                                    .frame(width: 24, height: 22)
                                
                                MiniVisualizerView(isPlaying: true, tintColor: AppTheme.neonCyan)
                            }
                        }
                    }
                    
                    // Название трека и источник
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(track.sourceName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Кнопки управления
                    HStack(spacing: 14) {
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .medium)
                            playerManager.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.neonCyan.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppTheme.neonCyan)
                            }
                        }
                        .buttonStyle(GlowingIconButtonStyle(glowColor: AppTheme.neonCyan))
                        
                        Button(action: {
                            HapticManager.shared.triggerImpact(style: .light)
                            playerManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(SpringScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                
                // Тонкий индикатор прогресса воспроизведения
                GeometryReader { geo in
                    let percent = playerManager.duration > 0 ? CGFloat(playerManager.currentTime / playerManager.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: geo.size.width * min(max(percent, 0.0), 1.0), height: 2.5)
                            .neonGlow(color: AppTheme.neonCyan, radius: 4, opacity: 0.6)
                    }
                }
                .frame(height: 2.5)
            }
            .liquidGlass(cornerRadius: 20, opacity: 0.65)
            .onTapGesture {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    isPlayerExpanded = true
                }
            }
        )
    }
}

