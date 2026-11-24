import SwiftUI

/// Очередь воспроизведения: текущий трек и «Далее».
/// Перетаскивание меняет порядок, свайп влево — убрать из очереди, тап — перейти к треку.
struct QueueView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationStack {
            List {
                if let current = player.currentTrack {
                    Section {
                        TrackRow(
                            artwork: current.artworkKey,
                            title: current.display.title,
                            subtitle: current.display.artist,
                            isCurrent: true,
                            isPlaying: player.playbackState == .playing
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        sectionTitle("Сейчас играет")
                    }
                }

                Section {
                    let upNext = player.upNext
                    if upNext.isEmpty {
                        Text("Дальше ничего нет. Добавьте треки через «Играть следующим» или «В конец очереди».")
                            .font(.appSubheadline)
                            .foregroundColor(Palette.textSecondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(upNext, id: \.id) { track in
                            Button {
                                HapticManager.shared.triggerSelection()
                                player.jumpToQueueTrack(id: track.id)
                            } label: {
                                TrackRow(
                                    artwork: track.artworkKey,
                                    title: track.display.title,
                                    subtitle: track.display.artist
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onMove { source, destination in
                            var reordered = player.upNext
                            reordered.move(fromOffsets: source, toOffset: destination)
                            player.replaceUpNext(with: reordered)
                        }
                        .onDelete { offsets in
                            let current = player.upNext
                            let ids = offsets.compactMap { current.indices.contains($0) ? current[$0].id : nil }
                            ids.forEach { player.removeFromQueue(trackId: $0) }
                        }
                    }
                } header: {
                    HStack {
                        sectionTitle("Далее")
                        Spacer()
                        queueModeButtons
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.backgroundRaised.ignoresSafeArea())
            .navigationTitle("Очередь")
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Palette.textPrimary)
            .textCase(nil)
    }

    private var queueModeButtons: some View {
        HStack(spacing: 6) {
            Button {
                HapticManager.shared.triggerSelection()
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(player.isShuffleEnabled ? .black : Palette.textPrimary)
                    .frame(width: 34, height: 30)
                    .background(Capsule().fill(player.isShuffleEnabled ? accent : Palette.surfaceStrong))
            }
            .accessibilityLabel("Перемешать")

            Button {
                HapticManager.shared.triggerSelection()
                player.toggleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(player.repeatMode == .none ? Palette.textPrimary : .black)
                    .frame(width: 34, height: 30)
                    .background(Capsule().fill(player.repeatMode == .none ? Palette.surfaceStrong : accent))
            }
            .accessibilityLabel("Повтор")
        }
        .buttonStyle(.plain)
    }
}
