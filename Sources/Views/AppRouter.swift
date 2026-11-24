import SwiftUI

/// Вкладки приложения
enum AppTab: Int, CaseIterable, Identifiable {
    case home
    case search
    case library
    case cloud

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .search: return "Поиск"
        case .library: return "Медиатека"
        case .cloud: return "Облако"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        case .cloud: return "cloud.fill"
        }
    }
}

/// Глобальная навигация: вкладки, плеер, общие листы и всплывающие уведомления
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let icon: String
    }

    @Published var selectedTab: AppTab = .home
    @Published var isPlayerExpanded = false
    @Published var isSettingsPresented = false
    @Published var addToPlaylistTrack: PlaylistTrack? = nil
    @Published var toast: Toast? = nil

    private var toastWorkItem: DispatchWorkItem?

    private init() {}

    func select(_ tab: AppTab) {
        HapticManager.shared.triggerSelection()
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTab = tab
        }
    }

    func expandPlayer() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isPlayerExpanded = true
        }
    }

    func collapsePlayer() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            isPlayerExpanded = false
        }
    }

    func addToPlaylist(_ track: PlaylistTrack) {
        addToPlaylistTrack = track
    }

    func showToast(_ message: String, icon: String = "checkmark.circle.fill") {
        toastWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toast = Toast(message: message, icon: icon)
        }
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
        toastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}
