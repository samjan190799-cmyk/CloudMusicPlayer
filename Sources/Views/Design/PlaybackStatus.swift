import Foundation
import Combine

/// Лёгкий наблюдатель за состоянием плеера для списков.
/// В отличие от AudioPlayerManager не публикует изменения каждую секунду
/// (currentTime), а только при смене трека или паузе — экраны не перерисовываются зря.
final class PlaybackStatus: ObservableObject {
    static let shared = PlaybackStatus()

    @Published private(set) var currentID: String? = nil
    @Published private(set) var isPlaying = false
    @Published private(set) var hasTrack = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let player = AudioPlayerManager.shared

        player.$currentTrack
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.currentID = id
                self?.hasTrack = id != nil
            }
            .store(in: &cancellables)

        player.$playbackState
            .map { $0 == .playing }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.isPlaying = playing
            }
            .store(in: &cancellables)
    }

    func isCurrent(_ id: String) -> Bool {
        currentID == id
    }

    func isPlayingTrack(_ id: String) -> Bool {
        currentID == id && isPlaying
    }
}
