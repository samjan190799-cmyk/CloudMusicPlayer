import SwiftUI
import UIKit

// MARK: - Палитра «Aurora»
//
// Тёмная многослойная основа, один акцентный цвет (выбирается в настройках)
// и динамический цвет текущей обложки в плеере.

enum Palette {
    /// Основной фон приложения
    static let background = Color(red: 0.039, green: 0.039, blue: 0.051)
    /// Приподнятый фон (листы, мини-плеер)
    static let backgroundRaised = Color(red: 0.075, green: 0.075, blue: 0.094)
    /// Поверхность карточек
    static let surface = Color.white.opacity(0.06)
    /// Более заметная поверхность (нажатые элементы, поля ввода)
    static let surfaceStrong = Color.white.opacity(0.10)
    /// Тонкая обводка
    static let stroke = Color.white.opacity(0.08)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static let danger = Color(red: 1.0, green: 0.36, blue: 0.38)
    static let success = Color(red: 0.24, green: 0.86, blue: 0.59)
}

// MARK: - Акцентные темы

enum AccentTheme: String, CaseIterable, Identifiable {
    case coral
    case violet
    case mint
    case sky
    case amber
    case rose

    static let storageKey = "accentTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: return "Коралл"
        case .violet: return "Фиалка"
        case .mint: return "Мята"
        case .sky: return "Небо"
        case .amber: return "Янтарь"
        case .rose: return "Роза"
        }
    }

    var color: Color {
        switch self {
        case .coral: return Color(red: 1.00, green: 0.42, blue: 0.33)
        case .violet: return Color(red: 0.56, green: 0.49, blue: 1.00)
        case .mint: return Color(red: 0.24, green: 0.86, blue: 0.62)
        case .sky: return Color(red: 0.29, green: 0.64, blue: 1.00)
        case .amber: return Color(red: 1.00, green: 0.70, blue: 0.22)
        case .rose: return Color(red: 1.00, green: 0.31, blue: 0.55)
        }
    }
}

// MARK: - Акцент через Environment

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = AccentTheme.coral.color
}

extension EnvironmentValues {
    /// Текущий акцентный цвет приложения
    var accent: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

/// Применяет тему приложения: акцент, tint и тёмную схему.
/// Вешается на корень и на корень каждого модального листа.
struct ThemedModifier: ViewModifier {
    @AppStorage(AccentTheme.storageKey) private var accentRaw = AccentTheme.coral.rawValue

    func body(content: Content) -> some View {
        let accent = (AccentTheme(rawValue: accentRaw) ?? .coral).color
        return content
            .environment(\.accent, accent)
            .tint(accent)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func themed() -> some View {
        modifier(ThemedModifier())
    }
}

// MARK: - Типографика

extension Font {
    static let appLargeTitle = Font.system(size: 32, weight: .bold)
    static let appTitle = Font.system(size: 22, weight: .bold)
    static let appHeadline = Font.system(size: 17, weight: .semibold)
    static let appRowTitle = Font.system(size: 16, weight: .semibold)
    static let appBody = Font.system(size: 15, weight: .regular)
    static let appSubheadline = Font.system(size: 14, weight: .regular)
    static let appCaption = Font.system(size: 12, weight: .medium)
}

// MARK: - Отступы и скругления

enum Metrics {
    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let artworkRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 30
}

// MARK: - Фон приложения

struct AppBackground: View {
    /// Цвет мягкого свечения сверху (по умолчанию — акцент)
    var glow: Color? = nil
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background
            LinearGradient(
                colors: [(glow ?? accent).opacity(0.28), (glow ?? accent).opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Модификаторы

extension View {
    /// Карточка на поверхности с тонкой обводкой
    func cardBackground(cornerRadius: CGFloat = Metrics.cardRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: 1)
        )
    }

    /// Скрывает системную навигационную панель на корневых экранах вкладок
    func hiddenNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }

    /// Стиль навигационной панели для вложенных экранов
    func appNavigationBar(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background.opacity(0.92), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Стили кнопок

/// Мягкое «нажатие» с пружиной
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Главная кнопка действия (залитая акцентом капсула)
struct PrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(accent))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Второстепенная кнопка (полупрозрачная капсула)
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Palette.surfaceStrong))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Размытие UIKit

struct VisualEffectBlur: UIViewRepresentable {
    var material: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: material))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: material)
    }
}

// MARK: - Форматирование

enum Formatters {
    /// 3:07 или 1:02:45
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// «1 ч 12 мин» или «12 мин»
    static func longDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        }
        return "\(max(minutes, 1)) мин"
    }

    static func bytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// «1 трек», «3 трека», «12 треков»
    static func tracks(_ count: Int) -> String {
        "\(count) \(plural(count, one: "трек", few: "трека", many: "треков"))"
    }

    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }
}
