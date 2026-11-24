import SwiftUI

/// Музыка из Telegram-бота: подключение по токену, поиск и онлайн-прослушивание
struct TelegramSourceView: View {
    @ObservedObject private var telegram = TelegramService.shared
    @ObservedObject private var status = PlaybackStatus.shared

    @State private var searchText = ""
    @State private var showDisconnect = false

    private var visibleTracks: [TelegramAudioTrack] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return telegram.tracks }
        return telegram.tracks.filter { track in
            track.name.localizedCaseInsensitiveContains(query)
                || (track.performer?.localizedCaseInsensitiveContains(query) ?? false)
                || (track.chatTitle?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if telegram.isAuthenticated {
                    connectedContent
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Подключите своего Telegram-бота: всё аудио, которое вы ему отправите или перешлёте, можно будет слушать здесь.")
                            .font(.appBody)
                            .foregroundColor(Palette.textSecondary)
                        TelegramConnectForm()
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            if telegram.isAuthenticated {
                telegram.fetchAudioTracks()
            }
        }
        .background(AppBackground(glow: Color(red: 0.16, green: 0.67, blue: 0.96)))
        .appNavigationBar(title: "Telegram")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if telegram.isAuthenticated {
                    Menu {
                        Button {
                            telegram.fetchAudioTracks()
                        } label: {
                            Label("Обновить", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            showDisconnect = true
                        } label: {
                            Label("Отключить бота", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .confirmationDialog("Отключить бота?", isPresented: $showDisconnect, titleVisibility: .visible) {
            Button("Отключить", role: .destructive) {
                telegram.logout()
            }
        }
    }

    @ViewBuilder
    private var connectedContent: some View {
        let tracks = visibleTracks

        HStack(spacing: 10) {
            Image(systemName: "paperplane.fill")
                .foregroundColor(Color(red: 0.16, green: 0.67, blue: 0.96))
            Text(telegram.botUsername)
                .font(.appHeadline)
                .foregroundColor(Palette.textPrimary)
            Spacer()
            if telegram.isLoading {
                ProgressView()
            }
        }
        .padding(.horizontal, Metrics.screenPadding)

        SearchField(text: $searchText, placeholder: "Поиск по Telegram")
            .padding(.horizontal, Metrics.screenPadding)

        if tracks.isEmpty && !telegram.isLoading {
            EmptyStateView(
                icon: "paperplane",
                title: searchText.isEmpty ? "Пока пусто" : "Ничего не найдено",
                message: searchText.isEmpty
                    ? "Отправьте боту аудиофайл или перешлите ему музыку, затем потяните экран вниз."
                    : "Попробуйте другое название.",
                actionTitle: searchText.isEmpty ? "Обновить" : nil
            ) {
                telegram.fetchAudioTracks()
            }
        } else {
            LazyVStack(spacing: 2) {
                ForEach(tracks) { track in
                    let display = CloudTracks.display(track)
                    let id = "tg_\(track.id)"
                    Button {
                        CloudTracks.playTelegram(track)
                    } label: {
                        TrackRow(
                            artwork: CloudTracks.artworkKey(track),
                            title: display.title,
                            subtitle: subtitle(for: track, artist: display.artist),
                            isCurrent: status.isCurrent(id),
                            isPlaying: status.isPlayingTrack(id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }

    private func subtitle(for track: TelegramAudioTrack, artist: String) -> String {
        var parts = [artist]
        if let duration = track.duration, duration > 0 {
            parts.append(Formatters.time(Double(duration)))
        }
        if let chat = track.chatTitle, !chat.isEmpty, chat != artist {
            parts.append(chat)
        }
        return parts.joined(separator: " · ")
    }
}
