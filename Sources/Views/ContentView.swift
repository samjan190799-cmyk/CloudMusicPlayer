import SwiftUI

/// Основной контейнер с вкладками в стиле Liquid Glass 2026
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isPlayerExpanded = false
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    init() {
        // Настройка полупрозрачного темного внешнего вида UITabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Динамический эмбиент фон
            AmbientBackgroundView()
            
            // Контент активной вкладки
            Group {
                switch selectedTab {
                case 0:
                    LibraryView()
                case 1:
                    AudiobooksView()
                case 2:
                    DownloadsView()
                case 3:
                    CloudHubView(selectedTab: $selectedTab)
                case 4:
                    YouTubeView()
                case 5:
                    SettingsView()
                default:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, playerManager.currentTrack != nil ? 142 : 82)
            .ignoresSafeArea(edges: .top)
            
            // Парящая панель плеера и стеклянный TabBar
            VStack(spacing: 10) {
                // Плавающий мини-плеер
                if playerManager.currentTrack != nil {
                    MiniPlayerView(isPlayerExpanded: $isPlayerExpanded)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
                
                // Кастомный стеклянный TabBar (Liquid Glass)
                customTabBar
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(isPresented: $isPlayerExpanded) {
            PlayerDetailView(isPlayerExpanded: $isPlayerExpanded)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Кастомный стеклянный TabBar (Liquid Glass)
    
    private var customTabBar: some View {
        HStack(spacing: 2) {
            tabButton(title: "Медиатека", icon: "folder.fill", index: 0)
            tabButton(title: "Книги", icon: "book.fill", index: 1)
            tabButton(title: "Загрузки", icon: "arrow.down.circle.fill", index: 2)
            tabButton(title: "Облако", icon: "cloud.fill", index: 3)
            tabButton(title: "YouTube", icon: "play.rectangle.fill", index: 4)
            tabButton(title: "Настройки", icon: "gearshape.fill", index: 5)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .liquidGlass(cornerRadius: 26, opacity: 0.6)
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                selectedTab = index
                HapticManager.shared.triggerSelection()
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppTheme.neonCyan.opacity(0.18))
                            .frame(width: 32, height: 32)
                            .blur(radius: 6)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? AppTheme.neonCyan : AppTheme.textMuted)
                        .shadow(color: isSelected ? AppTheme.neonCyan.opacity(0.5) : .clear, radius: 8)
                }
                .frame(height: 22)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? AppTheme.neonCyan : AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.neonCyan.opacity(0.3), lineWidth: 0.8)
                            )
                    }
                }
            )
        }
        .buttonStyle(SpringScaleButtonStyle())
    }
}

