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
        ZStack {
            // Корневой TabView
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Медиатека", systemName: "folder.fill")
                    }
                    .tag(0)
                
                CloudView(source: .google, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Google Диск", systemName: "cloud.fill")
                    }
                    .tag(1)
                
                CloudView(source: .yandex, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Яндекс Диск", systemName: "icloud.fill")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Настройки", systemName: "gearshape.fill")
                    }
                    .tag(3)
            }
            .accentColor(.cyan) // Активный цвет вкладок
            
            // Всплывающий мини-плеер внизу экрана
            if playerManager.currentTrack != nil {
                VStack {
                    Spacer()
                    MiniPlayerView(isPlayerExpanded: $isPlayerExpanded)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        // Открытие полноэкранного плеера
        .sheet(isPresented: $isPlayerExpanded) {
            PlayerDetailView(isPlayerExpanded: $isPlayerExpanded)
        }
        .preferredColorScheme(.dark)
    }
}
