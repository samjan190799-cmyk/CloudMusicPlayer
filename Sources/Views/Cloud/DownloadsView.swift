import SwiftUI

/// Скачанная музыка: активные загрузки, занятое место и список файлов
struct DownloadsView: View {
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var status = PlaybackStatus.shared
    @Environment(\.accent) private var accent

    @State private var showDeleteAll = false

    private var totalSize: Int64 {
        downloads.localTracks.reduce(Int64(0)) { $0 + $1.size }
    }

    private var sortedTracks: [LocalTrack] {
        downloads.localTracks.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        let tracks = sortedTracks
        let queue = tracks.map { $0.toPlayerTrack() }

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                storageCard
                    .padding(.horizontal, Metrics.screenPadding)

                let active = downloads.activeDownloadsList
                if !active.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Загружается")
                        VStack(spacing: 8) {
                            ForEach(active) { item in
                                activeRow(item)
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                    }
                }

                if tracks.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: "Нет скачанной музыки",
                        message: "Скачивайте треки из поиска и облака — они будут играть без интернета.",
                        actionTitle: "Перейти к поиску"
                    ) {
                        AppRouter.shared.select(.search)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Скачанное")
                        PlayShuffleButtons {
                            AudioPlayerManager.shared.playInOrder(queue)
                        } onShuffle: {
                            AudioPlayerManager.shared.playShuffled(queue)
                        }
                        .padding(.horizontal, Metrics.screenPadding)

                        LazyVStack(spacing: 2) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                row(track, playerTrack: queue[index]) {
                                    TrackActions.playOrToggle(queue[index], in: queue)
                                }
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .appNavigationBar(title: "Скачанное")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !downloads.localTracks.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAll = true
                        } label: {
                            Label("Удалить всё скачанное", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .confirmationDialog("Удалить всю скачанную музыку?", isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Удалить \(Formatters.tracks(downloads.localTracks.count))", role: .destructive) {
                let ids = downloads.localTracks.map { $0.id }
                ids.forEach { downloads.deleteTrack(trackId: $0) }
                AppRouter.shared.showToast("Скачанное удалено", icon: "trash.fill")
            }
        } message: {
            Text("Освободится \(Formatters.bytes(totalSize)). Плейлисты и избранное сохранятся.")
        }
    }

    // MARK: - Хранилище

    private var storageCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(Formatters.bytes(totalSize))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Palette.textPrimary)
                Text("\(Formatters.tracks(downloads.localTracks.count)) доступно офлайн")
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .cardBackground()
    }

    // MARK: - Строки

    private func activeRow(_ item: ActiveDownload) -> some View {
        let display = TrackText.display(title: item.title, artist: nil)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Palette.surfaceStrong, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(max(item.progress, 0.02)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: item.progress)
                Text("\(Int(item.progress * 100))")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Palette.textPrimary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .font(.appRowTitle)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(item.progress > 0 ? item.source.displayName : "Получаем ссылку…")
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Button {
                downloads.cancelDownload(trackId: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.surfaceStrong))
            }
            .accessibilityLabel("Отменить загрузку")
        }
        .padding(10)
        .cardBackground(cornerRadius: 14)
    }

    private func row(_ track: LocalTrack, playerTrack: PlayerTrack, onPlay: @escaping () -> Void) -> some View {
        let display = track.display
        let delete = {
            withAnimation {
                downloads.deleteTrack(trackId: track.id)
            }
        }

        return Button(action: onPlay) {
            TrackRow(
                artwork: track.artworkKey,
                title: display.title,
                subtitle: "\(display.artist) · \(Formatters.bytes(track.size))",
                isCurrent: status.isCurrent(track.id),
                isPlaying: status.isPlayingTrack(track.id)
            ) {
                Menu {
                    TrackMenuItems(track: playerTrack, onDelete: delete)
                } label: {
                    MoreMenuLabel()
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            TrackMenuItems(track: playerTrack, onDelete: delete)
        }
    }
}
