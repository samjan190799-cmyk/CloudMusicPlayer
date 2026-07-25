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
                    LibraryView()
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
            
            // Парящий мини-плеер справа снизу + плавающий стеклянный TabBar внизу
            VStack(alignment: .trailing, spacing: 14) {
                // Плавающий стеклянный виджет плеера справа снизу (как на референсном изображении)
                floatingMiniPlayerWidget
                    .padding(.trailing, 8)
                
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
    
    // MARK: - Плавающий мини-плеер справа снизу (как на изображении)
    
    private var floatingMiniPlayerWidget: some View {
        Button(action: {
            HapticManager.shared.triggerImpact(style: .medium)
            isPlayerExpanded = true
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.triggerSelection()
                        playerManager.togglePlayPause()
                    }) {
                        Image(systemName: playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        HapticManager.shared.triggerSelection()
                        playerManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Text(playerManager.currentTrack?.title ?? "Shivers")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    VisualEffectBlur(material: .systemUltraThinMaterialDark)
                    Color(red: 0.08, green: 0.08, blue: 0.18).opacity(0.85)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(SpringScaleButtonStyle())
    }
    
    // MARK: - Кастомный стеклянный TabBar (Liquid Glass)
    
    private var customTabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Explore", icon: "house.fill", index: 0)
            tabButton(title: "Recent", icon: "sparkle", index: 1)
            tabButton(title: "Search", icon: "magnifyingglass", index: 2)
            tabButton(title: "History", icon: "clock.fill", index: 3)
            tabButton(title: "Profile", icon: "person.fill", index: 4)
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
