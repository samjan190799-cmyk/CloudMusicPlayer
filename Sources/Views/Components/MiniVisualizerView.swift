import SwiftUI

/// Компактный анимированный визуализатор звука (микро-эквалайзер)
struct MiniVisualizerView: View {
    let isPlaying: Bool
    var tintColor: Color = .cyan
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: !isPlaying)) { context in
            HStack(alignment: .bottom, spacing: 1.8) {
                ForEach(0..<4, id: \.self) { index in
                    let randomHeight = isPlaying ? CGFloat.random(in: 0.3...1.0) : 0.2
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(LinearGradient(
                            colors: [tintColor, tintColor.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 2.0, height: 12 * randomHeight)
                }
            }
            .frame(width: 14, height: 12)
        }
    }
}
