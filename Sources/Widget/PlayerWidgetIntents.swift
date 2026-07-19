import AppIntents
import Foundation

// MARK: - Play / Pause

struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play / Pause"
    static var description = IntentDescription("Переключить воспроизведение музыки")
    /// false = выполняется в процессе виджета без открытия приложения
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        sendWidgetCommand("togglePlayPause")
        return .result()
    }
}

// MARK: - Skip Next

struct SkipNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Следующий трек"
    static var description = IntentDescription("Перейти к следующему треку")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        sendWidgetCommand("skipNext")
        return .result()
    }
}

// MARK: - Skip Previous

struct SkipPreviousIntent: AppIntent {
    static var title: LocalizedStringResource = "Предыдущий трек"
    static var description = IntentDescription("Вернуться к предыдущему треку")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        sendWidgetCommand("skipPrevious")
        return .result()
    }
}

// MARK: - Helpers

/// Записывает команду в shared UserDefaults и отправляет Darwin-уведомление основному приложению.
/// Darwin-уведомления — единственный надёжный способ IPC между Widget Extension и основным приложением.
private func sendWidgetCommand(_ command: String) {
    let defaults = UserDefaults(suiteName: kAppGroupID)
    defaults?.set(command, forKey: "pendingWidgetCommand")
    defaults?.synchronize()

    // CFNotificationCenter — кросс-процессный механизм (Darwin notify)
    let name = kDarwinCommandName as CFString
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(name),
        nil,
        nil,
        true
    )
}
