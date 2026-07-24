import SwiftUI
import UIKit

/// Единая система дизайна Liquid Glass 2026 для CloudMusicPlayer
enum AppTheme {
    // MARK: - Цветовая палитра
    
    static let spaceDark = Color(red: 0.04, green: 0.05, blue: 0.09)
    static let spaceDarker = Color(red: 0.02, green: 0.03, blue: 0.06)
    
    static let glassSurface = Color(red: 0.12, green: 0.14, blue: 0.24).opacity(0.45)
    static let glassSurfaceLight = Color.white.opacity(0.07)
    
    static let neonCyan = Color(red: 0.0, green: 0.92, blue: 1.0)
    static let neonPurple = Color(red: 0.65, green: 0.25, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.22, blue: 0.65)
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textMuted = Color.white.opacity(0.42)
    
    // MARK: - Градиенты
    
    static let primaryGradient = LinearGradient(
        colors: [neonCyan, neonPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [neonPurple, neonPink],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkBackgroundGradient = LinearGradient(
        colors: [spaceDark, Color(red: 0.07, green: 0.08, blue: 0.14)],
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
                        .fill(AppTheme.glassSurface.opacity(opacity))
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
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Применяет премиальный стеклянный стиль Liquid Glass
    func liquidGlass(cornerRadius: CGFloat = 22, opacity: Double = 0.5, borderColor: Color? = nil) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, borderColor: borderColor))
    }
    
    /// Добавляет неоновый отблеск по краям
    func neonGlow(color: Color = AppTheme.neonCyan, radius: CGFloat = 12, opacity: Double = 0.4) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Динамический Анимированный Эмбиент Фон

struct AmbientBackgroundView: View {
    var accentColor: Color = AppTheme.neonCyan
    var secondaryColor: Color = AppTheme.neonPurple
    
    @State private var animateBlobs = false
    
    var body: some View {
        ZStack {
            AppTheme.darkBackgroundGradient
                .ignoresSafeArea()
            
            // Живые разноцветные светящиеся шары на фоне (Hardware Accelerated Metal Rendering)
            GeometryReader { proxy in
                let size = proxy.size
                
                Circle()
                    .fill(accentColor.opacity(0.25))
                    .blur(radius: 60)
                    .frame(width: size.width * 0.85, height: size.width * 0.85)
                    .offset(
                        x: animateBlobs ? -size.width * 0.18 : size.width * 0.12,
                        y: animateBlobs ? -size.height * 0.12 : size.height * 0.08
                    )
                
                Circle()
                    .fill(secondaryColor.opacity(0.22))
                    .blur(radius: 70)
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .offset(
                        x: animateBlobs ? size.width * 0.22 : -size.width * 0.08,
                        y: animateBlobs ? size.height * 0.18 : -size.height * 0.04
                    )
                
                Circle()
                    .fill(AppTheme.neonPink.opacity(0.14))
                    .blur(radius: 75)
                    .frame(width: size.width * 0.7, height: size.width * 0.7)
                    .offset(
                        x: animateBlobs ? -size.width * 0.08 : size.width * 0.18,
                        y: animateBlobs ? size.height * 0.3 : size.height * 0.22
                    )
            }
            .drawingGroup() // Аппаратное ускорение Metal для предотвращения нагрева GPU/CPU
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 12.0)
                    .repeatForever(autoreverses: true)
                ) {
                    animateBlobs.toggle()
                }
            }

            
            // Легкий темный оверлей для идеальной читаемости
            Color.black.opacity(0.25)
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
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct GlowingIconButtonStyle: ButtonStyle {
    var glowColor: Color = AppTheme.neonCyan
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .shadow(color: glowColor.opacity(configuration.isPressed ? 0.6 : 0.25), radius: configuration.isPressed ? 12 : 6)
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

