import SwiftUI
import PhotosUI

/// Страница плейлиста: обложка, «Слушать / Перемешать», треки и управление
struct PlaylistDetailView: View {
    let playlistID: UUID

    @ObservedObject private var manager = PlaylistManager.shared
    @ObservedObject private var status = PlaybackStatus.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    private var playlist: Playlist? {
        manager.playlists.first(where: { $0.id == playlistID })
    }

    private var isFavorites: Bool {
        playlistID == PlaylistManager.favoritesUUID
    }

    var body: some View {
        Group {
            if let playlist = playlist {
                content(playlist)
            } else {
                EmptyStateView(icon: "music.note.list", title: "Плейлист удалён", message: "Этого плейлиста больше нет.")
            }
        }
        .background(AppBackground(glow: glowColor))
        .appNavigationBar(title: playlist?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Выбрать обложку", systemImage: "photo")
                    }
                    if !isFavorites {
                        Button {
                            renameText = playlist?.name ?? ""
                            showRename = true
                        } label: {
                            Label("Переименовать", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Удалить плейлист", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        manager.setCoverImage(image, for: playlistID)
                        HapticManager.shared.triggerNotification(type: .success)
                    }
                }
                await MainActor.run {
                    selectedPhoto = nil
                }
            }
        }
        .alert("Переименовать плейлист", isPresented: $showRename) {
            TextField("Название", text: $renameText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                manager.renamePlaylist(id: playlistID, to: renameText)
            }
        }
        .confirmationDialog("Удалить плейлист?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                manager.deletePlaylist(id: playlistID)
                dismiss()
            }
        } message: {
            Text("Треки останутся в медиатеке.")
        }
    }

    private var glowColor: Color {
        if isFavorites {
            return Color(red: 1.0, green: 0.36, blue: 0.48)
        }
        return GeneratedArtwork.colors(for: playlistID.uuidString).0
    }

    // MARK: - Контент

    private func content(_ playlist: Playlist) -> some View {
        let queue = playlist.tracks.map { $0.toPlayerTrack() }
        let totalDuration = playlist.tracks.compactMap { $0.duration }.reduce(0, +)

        return ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    PlaylistArtwork(playlist: playlist, cornerRadius: 16)
                        .frame(width: 220, height: 220)
                        .shadow(color: Color.black.opacity(0.5), radius: 26, x: 0, y: 14)

                    VStack(spacing: 4) {
                        Text(playlist.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(subtitle(count: playlist.tracks.count, duration: totalDuration))
                            .font(.appSubheadline)
                            .foregroundColor(Palette.textSecondary)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, Metrics.screenPadding)

                if playlist.tracks.isEmpty {
                    EmptyStateView(
                        icon: isFavorites ? "heart" : "music.note",
                        title: isFavorites ? "Здесь будут любимые треки" : "Плейлист пуст",
                        message: isFavorites
                            ? "Нажмите ♥ в плеере или дважды коснитесь обложки, чтобы добавить трек."
                            : "Откройте меню «…» у любого трека и выберите «Добавить в плейлист».",
                        actionTitle: "Найти музыку"
                    ) {
                        AppRouter.shared.select(.search)
                    }
                } else {
                    PlayShuffleButtons {
                        AudioPlayerManager.shared.playInOrder(queue)
                    } onShuffle: {
                        AudioPlayerManager.shared.playShuffled(queue)
                    }
                    .padding(.horizontal, Metrics.screenPadding)

                    LazyVStack(spacing: 2) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            row(track: track, playerTrack: queue[index]) {
                                AudioPlayerManager.shared.play(track: queue[index], in: queue)
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func subtitle(count: Int, duration: Double) -> String {
        guard duration > 0 else { return Formatters.tracks(count) }
        return "\(Formatters.tracks(count)) · \(Formatters.longDuration(duration))"
    }

    private func row(track: PlaylistTrack, playerTrack: PlayerTrack, onPlay: @escaping () -> Void) -> some View {
        let display = track.display
        let remove = {
            withAnimation {
                manager.removeTrack(trackId: track.id, from: playlistID)
            }
        }

        return Button(action: onPlay) {
            TrackRow(
                artwork: track.artworkKey,
                title: display.title,
                subtitle: display.artist,
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id)
            ) {
                Menu {
                    TrackMenuItems(
                        track: playerTrack,
                        onDownload: TrackActions.canDownload(playerTrack) ? { _ = TrackActions.download(playerTrack) } : nil,
                        onRemoveFromPlaylist: remove
                    )
                } label: {
                    MoreMenuLabel()
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            TrackMenuItems(
                track: playerTrack,
                onDownload: TrackActions.canDownload(playerTrack) ? { _ = TrackActions.download(playerTrack) } : nil,
                onRemoveFromPlaylist: remove
            )
        }
    }
}
