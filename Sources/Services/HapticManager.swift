import UIKit

/// Менеджер тактильной отдачи (Haptic Feedback) для iOS
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Легкий щелчок для кнопок, переключателей и табов
    func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Тактильный отклик для уведомлений (успех, предупреждение, ошибка)
    func triggerNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    /// Тактильный отклик для изменения выбора (например, при переключении пикеров)
    func triggerSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
