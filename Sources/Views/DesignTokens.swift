import SwiftUI
import UIKit

/// Единая дизайн-система Obsidian Monochrome Luxe 2026 для CloudMusicPlayer
enum AppTheme {
    // MARK: - Монохромная палитра (Pure Black & Platinum White)
    
    static let pureBlack = Color.black
    static let spaceDark = Color(red: 0.03, green: 0.03, blue: 0.04)
    static let spaceDarker = Color(red: 0.015, green: 0.015, blue: 0.02)
    static let obsidianSurface = Color(red: 0.08, green: 0.08, blue: 0.10)
    
    static let glassSurface = Color.white.opacity(0.06)
    static let glassSurfaceLight = Color.white.opacity(0.10)
    
    // Монохромные акценты (чистый белый и полированное серебро)
    static let accentWhite = Color.white
    static let accentSilver = Color(white: 0.85)
    static let accentMuted = Color(white: 0.45)
    
    // Совместимость со старыми токенами — приведены к чистой монохромной гамме
    static let neonCyan = Color.white
    static let neonPurple = Color(white: 0.88)
    static let neonPink = Color(white: 0.72)
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textMuted = Color.white.opacity(0.42)
    
    // MARK: - Премиальные Градиенты
    
    static let primaryGradient = LinearGradient(
        colors: [Color.white, Color(white: 0.80)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color.white, Color(white: 0.60)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkBackgroundGradient = LinearGradient(
        colors: [Color.black, Color(red: 0.04, green: 0.04, blue: 0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Modifiers

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double
    var borderColor: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.04 * opacity))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        borderColor != nil ? AnyShapeStyle(borderColor!) : AnyShapeStyle(AppTheme.glassBorder),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.55), radius: 14, x: 0, y: 7)
    }
}

extension View {
    /// Применяет премиальный стиль темного матового стекла Obsidian Glass
    func liquidGlass(cornerRadius: CGFloat = 22, opacity: Double = 0.5, borderColor: Color? = nil) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, borderColor: borderColor))
    }
    
    /// Добавляет деликатное лунное свечение (Moonlight Glow)
    func neonGlow(color: Color = Color.white, radius: CGFloat = 12, opacity: Double = 0.3) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Динамический Обсидиановый Фон (Obsidian Ambient Background)

struct AmbientBackgroundView: View {
    var accentColor: Color = Color.white
    var secondaryColor: Color = Color(white: 0.8)
    
    @State private var animateGlow = false
    
    var body: some View {
        ZStack {
            // Глубокий обсидиановый OLED-фон
            AppTheme.darkBackgroundGradient
                .ignoresSafeArea()
            
            // Мягкое лунное свечение (Moonlight Aura)
            GeometryReader { proxy in
                let size = proxy.size
                
                Circle()
                    .fill(Color.white.opacity(0.035))
                    .blur(radius: 80)
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .offset(
                        x: animateGlow ? -size.width * 0.1 : size.width * 0.1,
                        y: animateGlow ? -size.height * 0.08 : size.height * 0.06
                    )
                
                Circle()
                    .fill(Color(white: 0.9).opacity(0.025))
                    .blur(radius: 95)
                    .frame(width: size.width * 1.0, height: size.width * 1.0)
                    .offset(
                        x: animateGlow ? size.width * 0.12 : -size.width * 0.06,
                        y: animateGlow ? size.height * 0.15 : -size.height * 0.05
                    )
            }
            .drawingGroup()
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 10.0)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGlow.toggle()
                }
            }
            
            // Полупрозрачный черный оверлей для максимального контраста
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Стили для Кнопок

struct SpringScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct GlowingIconButtonStyle: ButtonStyle {
    var glowColor: Color = Color.white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .shadow(color: glowColor.opacity(configuration.isPressed ? 0.45 : 0.15), radius: configuration.isPressed ? 12 : 5)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Стеклянный Blur Эффект для UIKit / SwiftUI

struct VisualEffectBlur: UIViewRepresentable {
    var material: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: material))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
