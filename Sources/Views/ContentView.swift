import SwiftUI

/// Корневой экран: вкладки, плавающий мини-плеер, полноэкранный плеер и общие листы
struct ContentView: View {
    @ObservedObject private var router = AppRouter.shared
    @ObservedObject private var status = PlaybackStatus.shared

    /// Вкладки создаются при первом открытии и дальше живут в фоне —
    /// так сохраняются прокрутка и навигация при переключении
    @State private var visitedTabs: Set<AppTab> = [.home]

    var body: some View {
        ZStack {
            Palette.background
                .ignoresSafeArea()

            tabContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                }

            if router.isPlayerExpanded && status.hasTrack {
                NowPlayingView()
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }

            if let toast = router.toast {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(3)
                .allowsHitTesting(false)
            }
        }
        .sheet(item: $router.addToPlaylistTrack) { track in
            AddToPlaylistView(track: track)
                .themed()
        }
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView()
                .themed()
        }
        .onChange(of: router.selectedTab) { tab in
            visitedTabs.insert(tab)
        }
        .onChange(of: status.hasTrack) { hasTrack in
            if !hasTrack {
                router.isPlayerExpanded = false
            }
        }
    }

    // MARK: - Вкладки

    private var tabContent: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                if visitedTabs.contains(tab) || router.selectedTab == tab {
                    tabView(for: tab)
                        .opacity(router.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(router.selectedTab == tab)
                        .accessibilityHidden(router.selectedTab != tab)
                }
            }
        }
    }

    @ViewBuilder
    private func tabView(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .search:
            ExploreView()
        case .library:
            LibraryView()
        case .cloud:
            CloudHubView()
        }
    }

    // MARK: - Нижняя панель (мини-плеер + таб-бар)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if status.hasTrack {
                MiniPlayerView()
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            AppTabBar()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: status.hasTrack)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Palette.background.opacity(0.0), location: 0.0),
                    .init(color: Palette.background.opacity(0.88), location: 0.3),
                    .init(color: Palette.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Таб-бар

struct AppTabBar: View {
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = router.selectedTab == tab
                Button {
                    if !isSelected {
                        router.select(tab)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 24)
                        Text(tab.title)
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? accent : Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
    }
}
