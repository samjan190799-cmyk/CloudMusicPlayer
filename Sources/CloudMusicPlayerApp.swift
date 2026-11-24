import SwiftUI
import AVFoundation

@main
struct CloudMusicPlayerApp: App {
    
    init() {
        setupBackgroundAudio()
        URLProtocol.registerClass(YouTubeURLProtocol.self)
        _ = YouTubeSessionManager.shared
        // История и цвет обложки следят за текущим треком с самого старта
        _ = ListeningHistory.shared
        _ = NowPlayingArtwork.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .themed()
                .onOpenURL { url in
                    TelegramShareManager.shared.handleIncomingAudioURL(url)
                }
        }
    }
    
    /// Настройка фонового воспроизведения аудио на уровне старта приложения
    private func setupBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            print("AVAudioSession успешно настроен для фонового аудио.")
        } catch {
            print("Ошибка при начальной настройке AVAudioSession: \(error.localizedDescription)")
        }
    }
}
