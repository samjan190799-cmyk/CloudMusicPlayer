import SwiftUI

/// Лист «Добавить в плейлист». Галочка показывает, где трек уже есть; повторный тап убирает его.
struct AddToPlaylistView: View {
    let track: PlaylistTrack

    @ObservedObject private var manager = PlaylistManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TrackRow(
                        artwork: track.artworkKey,
                        title: track.display.title,
                        subtitle: track.display.artist
                    )
                    .padding(12)
                    .cardBackground(cornerRadius: 14)

                    Button {
                        showCreate = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(accent)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(accent.opacity(0.15))
                                )
                            Text("Новый плейлист")
                                .font(.appRowTitle)
                                .foregroundColor(Palette.textPrimary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))

                    VStack(spacing: 6) {
                        ForEach(manager.playlists) { playlist in
                            playlistRow(playlist)
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .scrollIndicators(.hidden)
            .background(Palette.backgroundRaised.ignoresSafeArea())
            .navigationTitle("Добавить в плейлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.backgroundRaised, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
            .createPlaylistAlert(isPresented: $showCreate) { created in
                manager.addTrack(track, to: created.id)
                AppRouter.shared.showToast("Добавлено в «\(created.name)»", icon: "text.badge.plus")
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func playlistRow(_ playlist: Playlist) -> some View {
        let contains = playlist.tracks.contains(where: { $0.id == track.id })

        return Button {
            HapticManager.shared.triggerImpact(style: .light)
            if contains {
                manager.removeTrack(trackId: track.id, from: playlist.id)
            } else if playlist.id == PlaylistManager.favoritesUUID {
                manager.toggleFavorite(track: track)
                AppRouter.shared.showToast("Добавлено в избранное", icon: "heart.fill")
            } else {
                manager.addTrack(track, to: playlist.id)
                AppRouter.shared.showToast("Добавлено в «\(playlist.name)»", icon: "text.badge.plus")
            }
        } label: {
            HStack(spacing: 14) {
                PlaylistArtwork(playlist: playlist, cornerRadius: 8)
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.appRowTitle)
                        .foregroundColor(Palette.textPrimary)
                        .lineLimit(1)
                    Text(Formatters.tracks(playlist.tracks.count))
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: contains ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(contains ? accent : Palette.textTertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
