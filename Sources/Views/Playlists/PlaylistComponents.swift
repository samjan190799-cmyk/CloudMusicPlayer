import SwiftUI

// MARK: - Карточка плейлиста

struct PlaylistCard: View {
    let playlist: Playlist
    var width: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlaylistArtwork(playlist: playlist, cornerRadius: 12)
                .frame(width: width, height: width)
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(Formatters.tracks(playlist.tracks.count))
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Плитка «Новый плейлист»
struct NewPlaylistCard: View {
    var width: CGFloat = 148
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundColor(Palette.textTertiary)
                .frame(width: width, height: width)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(accent)
                )
            Text("Новый плейлист")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
            Text(" ")
                .font(.system(size: 13))
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Создание плейлиста

struct CreatePlaylistAlert: ViewModifier {
    @Binding var isPresented: Bool
    var onCreated: ((Playlist) -> Void)? = nil

    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Новый плейлист", isPresented: $isPresented) {
                TextField("Название", text: $name)
                Button("Отмена", role: .cancel) {
                    name = ""
                }
                Button("Создать") {
                    create()
                }
            } message: {
                Text("Придумайте название для плейлиста")
            }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = ""
        guard !trimmed.isEmpty else { return }
        let manager = PlaylistManager.shared
        manager.createPlaylist(name: trimmed)
        HapticManager.shared.triggerNotification(type: .success)
        AppRouter.shared.showToast("Плейлист «\(trimmed)» создан", icon: "music.note.list")
        if let created = manager.playlists.last {
            onCreated?(created)
        }
    }
}

extension View {
    func createPlaylistAlert(isPresented: Binding<Bool>, onCreated: ((Playlist) -> Void)? = nil) -> some View {
        modifier(CreatePlaylistAlert(isPresented: isPresented, onCreated: onCreated))
    }
}
