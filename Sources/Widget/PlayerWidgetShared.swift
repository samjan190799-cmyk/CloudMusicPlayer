import Foundation

// MARK: - App Group identifier
let kAppGroupID = "group.com.samvel.cloudmusicplayer"
let kDarwinCommandName = "com.samvel.cloudmusicplayer.widgetCommand"

// MARK: - Shared state model (используется и в приложении, и в виджете)
struct SharedPlayerState: Codable {
    var trackTitle: String
    var artistName: String
    var isPlaying: Bool
    /// PNG обложки, max 200×200, nil если нет
    var coverData: Data?

    static let empty = SharedPlayerState(
        trackTitle: "CloudMusicPlayer",
        artistName: "Нет трека",
        isPlaying: false,
        coverData: nil
    )

    // MARK: - Persistence via App Group UserDefaults

    private static let key = "sharedPlayerState"

    static func load() -> SharedPlayerState {
        guard
            let defaults = UserDefaults(suiteName: kAppGroupID),
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(SharedPlayerState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func save() {
        guard
            let defaults = UserDefaults(suiteName: kAppGroupID),
            let data = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(data, forKey: SharedPlayerState.key)
        defaults.synchronize()
    }
}
