import SwiftUI
import AVFoundation

@main
struct CloudMusicPlayerApp: App {
    
    init() {
        setupBackgroundAudio()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    /// Настройка фонового воспроизведения аудио на уровне старта приложения
    private func setupBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .defaultToSpeaker])
            try session.setActive(true)
            print("AVAudioSession успешно настроен для фонового аудио.")
        } catch {
            print("Ошибка при начальной настройке AVAudioSession: \(error.localizedDescription)")
        }
    }
}
