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
            HStack(spacing: 12) {
                // Иконка/обложка
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                        .font(.title3)
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
                        playerManager.togglePlayPause()
                    }) {
                        Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                    
                    Button(action: {
                        playerManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .background(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 12)
            .padding(.bottom, 60) // Отступ от нижнего бара
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isPlayerExpanded = true
                }
            }
        )
    }
}
