import SwiftUI

// MARK: - Индикатор воспроизведения (три «прыгающих» столбика)

struct PlayingBars: View {
    var isAnimating: Bool
    var color: Color = .white
    var height: CGFloat = 14

    private let speeds: [Double] = [5.3, 7.1, 6.2]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let level = isAnimating ? 0.3 + 0.7 * abs(sin(time * speeds[index] + Double(index) * 1.3)) : 0.35
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: max(3, height * level))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
    }
}

// MARK: - Заголовок секции

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.accent) private var accent

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appTitle)
                    .foregroundColor(Palette.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundColor(Palette.textTertiary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
    }
}

// MARK: - Строка трека

struct TrackRow<Accessory: View>: View {
    let artwork: ArtworkKey
    let title: String
    let subtitle: String
    var isCurrent: Bool
    var isPlaying: Bool
    var number: Int?
    let accessory: Accessory

    @Environment(\.accent) private var accent

    init(
        artwork: ArtworkKey,
        title: String,
        subtitle: String,
        isCurrent: Bool = false,
        isPlaying: Bool = false,
        number: Int? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.artwork = artwork
        self.title = title
        self.subtitle = subtitle
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.number = number
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let number = number {
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isCurrent ? accent : Palette.textTertiary)
                    .monospacedDigit()
                    .frame(width: 24)
            }

            ZStack {
                ArtworkView(artwork: artwork, cornerRadius: 8, maxPixel: 160)
                if isCurrent {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                    PlayingBars(isAnimating: isPlaying, color: .white, height: 16)
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appRowTitle)
                    .foregroundColor(isCurrent ? accent : Palette.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            accessory
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

extension TrackRow where Accessory == EmptyView {
    init(
        artwork: ArtworkKey,
        title: String,
        subtitle: String,
        isCurrent: Bool = false,
        isPlaying: Bool = false,
        number: Int? = nil
    ) {
        self.init(
            artwork: artwork,
            title: title,
            subtitle: subtitle,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            number: number
        ) {
            EmptyView()
        }
    }
}

/// Кнопка «…» для строк треков
struct MoreMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Palette.textSecondary)
            .frame(width: 36, height: 44)
            .contentShape(Rectangle())
    }
}

// MARK: - Действия с треком (меню и контекстное меню)

struct TrackMenuItems: View {
    let track: PlayerTrack
    var onDownload: (() -> Void)? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var deleteTitle: String = "Удалить с устройства"

    @ObservedObject private var playlistManager = PlaylistManager.shared

    var body: some View {
        let isFavorite = playlistManager.isTrackFavorite(trackId: track.id)

        Button {
            AudioPlayerManager.shared.playNext(track)
            AppRouter.shared.showToast("Сыграет следующим", icon: "text.insert")
        } label: {
            Label("Играть следующим", systemImage: "text.insert")
        }

        Button {
            AudioPlayerManager.shared.addToQueue(track)
            AppRouter.shared.showToast("Добавлено в очередь", icon: "text.append")
        } label: {
            Label("В конец очереди", systemImage: "text.append")
        }

        Divider()

        Button {
            playlistManager.toggleFavorite(track: track.toPlaylistTrack())
            HapticManager.shared.triggerImpact(style: .light)
            AppRouter.shared.showToast(isFavorite ? "Убрано из избранного" : "Добавлено в избранное", icon: isFavorite ? "heart.slash" : "heart.fill")
        } label: {
            Label(isFavorite ? "Убрать из избранного" : "В избранное", systemImage: isFavorite ? "heart.slash" : "heart")
        }

        Button {
            AppRouter.shared.addToPlaylist(track.toPlaylistTrack())
        } label: {
            Label("Добавить в плейлист", systemImage: "text.badge.plus")
        }

        if let onDownload = onDownload {
            Button(action: onDownload) {
                Label("Скачать", systemImage: "arrow.down.circle")
            }
        }

        if let onRemoveFromPlaylist = onRemoveFromPlaylist {
            Divider()
            Button(role: .destructive, action: onRemoveFromPlaylist) {
                Label("Убрать из плейлиста", systemImage: "minus.circle")
            }
        }

        if let onDelete = onDelete {
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(deleteTitle, systemImage: "trash")
            }
        }
    }
}

// MARK: - Статус загрузки

struct DownloadStatusButton: View {
    let status: DownloadStatus
    let onDownload: () -> Void
    let onCancel: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        switch status {
        case .notDownloaded:
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Palette.textSecondary)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(PressableButtonStyle())
        case .downloading(let progress):
            Button(action: onCancel) {
                ZStack {
                    Circle()
                        .stroke(Palette.surfaceStrong, lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(progress, 0.03)))
                        .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: progress)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 22, height: 22)
                .frame(width: 36, height: 44)
            }
            .buttonStyle(PressableButtonStyle())
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(accent)
                .frame(width: 36, height: 44)
        case .failed:
            Button(action: onDownload) {
                Image(systemName: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Palette.danger)
                    .frame(width: 36, height: 44)
            }
        }
    }
}

/// Кнопка загрузки, которая сама следит за прогрессом —
/// экран целиком не перерисовывается на каждый тик загрузки
struct LiveDownloadButton: View {
    let trackID: String
    let onDownload: () -> Void

    @ObservedObject private var downloads = DownloadManager.shared

    var body: some View {
        DownloadStatusButton(
            status: downloads.getDownloadStatus(for: trackID),
            onDownload: onDownload,
            onCancel: {
                downloads.cancelDownload(trackId: trackID)
            }
        )
    }
}

// MARK: - Пустое состояние

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(accent)
            }
            Text(title)
                .font(.appHeadline)
                .foregroundColor(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.appSubheadline)
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Поле поиска

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Поиск"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.textTertiary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.textTertiary))
                .font(.appBody)
                .foregroundColor(Palette.textPrimary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surfaceStrong)
        )
    }
}

// MARK: - Чипы-фильтры

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: {
            HapticManager.shared.triggerSelection()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : Palette.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule().fill(isSelected ? accent : Palette.surfaceStrong)
                )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Круглая кнопка-иконка

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    var iconSize: CGFloat = 16
    var background: Color = Palette.surfaceStrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
    }
}

// MARK: - Кнопки «Слушать» / «Перемешать»

struct PlayShuffleButtons: View {
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Label("Слушать", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())

            Button(action: onShuffle) {
                Label("Перемешать", systemImage: "shuffle")
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
        }
    }
}

// MARK: - Карточка трека для каруселей

struct MediaCard: View {
    let artwork: ArtworkKey
    let title: String
    let subtitle: String
    var width: CGFloat = 148
    var isCurrent: Bool = false
    var isPlaying: Bool = false

    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ArtworkView(artwork: artwork, cornerRadius: 12, maxPixel: width * 2.5)
                    .frame(width: width, height: width)
                if isCurrent {
                    PlayingBars(isAnimating: isPlaying, color: .black, height: 14)
                        .padding(7)
                        .background(Circle().fill(accent))
                        .padding(8)
                }
            }
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrent ? accent : Palette.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Обложка плейлиста (своё фото, мозаика или градиент)

struct PlaylistArtwork: View {
    let playlist: Playlist
    var cornerRadius: CGFloat = 12

    private var isFavorites: Bool { playlist.id == PlaylistManager.favoritesUUID }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            content(side: side)
                .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func content(side: CGFloat) -> some View {
        if let coverURL = playlist.coverURL, FileManager.default.fileExists(atPath: coverURL.path) {
            ArtworkView(
                artwork: ArtworkKey(id: playlist.id.uuidString, title: playlist.name, localCoverURL: coverURL, youTubeID: nil),
                cornerRadius: 0,
                maxPixel: side * 3
            )
        } else if isFavorites {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.36, blue: 0.48), Color(red: 0.42, green: 0.16, blue: 0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "heart.fill")
                    .font(.system(size: side * 0.34, weight: .semibold))
                    .foregroundColor(.white)
            }
        } else if playlist.tracks.count >= 4 {
            let tiles = Array(playlist.tracks.prefix(4))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tile(tiles[0], side: side / 2)
                    tile(tiles[1], side: side / 2)
                }
                HStack(spacing: 0) {
                    tile(tiles[2], side: side / 2)
                    tile(tiles[3], side: side / 2)
                }
            }
        } else if let first = playlist.tracks.first {
            ArtworkView(artwork: first.artworkKey, cornerRadius: 0, maxPixel: side * 3)
        } else {
            GeneratedCover(seed: playlist.id.uuidString, title: playlist.name, symbol: "music.note.list")
        }
    }

    private func tile(_ track: PlaylistTrack, side: CGFloat) -> some View {
        ArtworkView(artwork: track.artworkKey, cornerRadius: 0, maxPixel: side * 3)
            .frame(width: side, height: side)
    }
}

// MARK: - Всплывающее уведомление

struct ToastView: View {
    let toast: AppRouter.Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 15, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Palette.backgroundRaised.opacity(0.96))
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
    }
}
