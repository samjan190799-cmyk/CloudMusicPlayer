import SwiftUI

/// Основной контейнер с вкладками
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isPlayerExpanded = false
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    init() {
        // Настройка полупрозрачного темного внешнего вида UITabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 0.85)
        
        // Blur эффект для TabBar
        let blurEffect = UIBlurEffect(style: .dark)
        appearance.backgroundEffect = blurEffect
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
            .padding(.bottom, playerManager.currentTrack != nil ? 150 : 85) // Отступ для парящих панелей
            .ignoresSafeArea(edges: .top)
            
            // Всплывающие панели управления
            VStack(spacing: 12) {
                // Мини-плеер
                if playerManager.currentTrack != nil {
                    MiniPlayerView(isPlayerExpanded: $isPlayerExpanded)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Кастомный стеклянный TabBar
                customTabBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(isPresented: $isPlayerExpanded) {
            PlayerDetailView(isPlayerExpanded: $isPlayerExpanded)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Кастомный стеклянный TabBar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Медиатека", icon: "folder.fill", index: 0)
            tabButton(title: "Загрузки", icon: "arrow.down.circle.fill", index: 1)
            tabButton(title: "Облако", icon: "cloud.fill", index: 2)
            tabButton(title: "YouTube", icon: "play.rectangle.fill", index: 3)
            tabButton(title: "Настройки", icon: "gearshape.fill", index: 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.15).opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.purple.opacity(0.03))
                )
                .background(VisualEffectBlur(material: .systemUltraThinMaterial, blendingMode: .withinWindow))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 10)
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = index
                HapticManager.shared.triggerSelection()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.45))
                    .frame(height: 22)
                    .shadow(color: isSelected ? .cyan.opacity(0.3) : .clear, radius: 4)
                
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        Color.white.opacity(0.04)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Системный размыватель для Glassmorphism

struct VisualEffectBlur: UIViewRepresentable {
    var material: UIBlurEffect.Style
    var blendingMode: UIVisualEffectView.BlendingMode = .withinWindow
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: material))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
