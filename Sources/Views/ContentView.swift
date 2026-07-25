import SwiftUI

/// Основной контейнер с вкладками в стиле Liquid Glass 2026 (Точно по референсному дизайну)
struct ContentView: View {
    @State private var selectedTab = 1 // 0: Explore, 1: Recent, 2: Search, 3: History, 4: Profile
    @State private var isPlayerExpanded = false
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Динамический глубокий фиолетово-космический фон
            AmbientBackgroundView(
                accentColor: Color(red: 0.45, green: 0.25, blue: 0.95),
                secondaryColor: Color(red: 0.15, green: 0.45, blue: 0.95)
            )
            
            // Контент активной вкладки
            Group {
                switch selectedTab {
                case 0:
                    LibraryView()
                case 1:
                    DownloadsView()
                case 2:
                    CloudHubView(selectedTab: $selectedTab)
                case 3:
                    YouTubeView()
                case 4:
                    SettingsView()
                default:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 90)
            .ignoresSafeArea(edges: .top)
            
            // Полноценный стеклянный Мини-плеер + плавающий стеклянный TabBar внизу
            VStack(spacing: 8) {
                if playerManager.currentTrack != nil {
                    MiniPlayerView(isPlayerExpanded: $isPlayerExpanded)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Кастомный парящий стеклянный TabBar (Liquid Glass)
                customTabBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(isPresented: $isPlayerExpanded) {
            PlayerDetailView(isPlayerExpanded: $isPlayerExpanded)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Кастомный стеклянный TabBar (Liquid Glass)
    
    private var customTabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Медиатека", icon: "music.note.house.fill", index: 0)
            tabButton(title: "Загрузки", icon: "arrow.down.circle.fill", index: 1)
            tabButton(title: "Облако", icon: "cloud.fill", index: 2)
            tabButton(title: "YouTube", icon: "play.rectangle.fill", index: 3)
            tabButton(title: "Настройки", icon: "gearshape.fill", index: 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                VisualEffectBlur(material: .systemUltraThinMaterialDark)
                Color.white.opacity(0.08)
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 10)
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
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.25, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.6), radius: 10, x: 0, y: 2)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                }
                .frame(height: 28)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(SpringScaleButtonStyle())
    }
}
