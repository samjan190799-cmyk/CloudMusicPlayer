import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct PlayerEntry: TimelineEntry {
    let date: Date
    let state: SharedPlayerState
}

// MARK: - Timeline Provider

struct PlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlayerEntry {
        PlayerEntry(date: Date(), state: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlayerEntry) -> Void) {
        completion(PlayerEntry(date: Date(), state: SharedPlayerState.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlayerEntry>) -> Void) {
        let entry = PlayerEntry(date: Date(), state: SharedPlayerState.load())
        // Обновляем каждые 30 сек как fallback; основной тригер — reloadAllTimelines() из приложения
        let next = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Helper: Cover Image

private func coverImage(from data: Data?) -> Image {
    if let d = data, let ui = UIImage(data: d) {
        return Image(uiImage: ui)
    }
    return Image(systemName: "music.note")
}

// MARK: - Small Widget (рабочий стол, маленький)

struct PlayerWidgetSmallView: View {
    let entry: PlayerEntry

    var body: some View {
        ZStack {
            // Фон — размытая обложка
            if let d = entry.state.coverData, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .overlay(Color.black.opacity(0.55))
            } else {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.04, blue: 0.18),
                             Color(red: 0.04, green: 0.09, blue: 0.28)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            VStack(spacing: 10) {
                // Обложка
                coverThumbnail(size: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 6)

                // Название (одна строка)
                Text(entry.state.trackTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)

                // Кнопка Play/Pause
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: TogglePlayPauseIntent()) {
                        Image(systemName: entry.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 30))
                            .shadow(color: .cyan.opacity(0.45), radius: 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: entry.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 30))
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func coverThumbnail(size: CGFloat) -> some View {
        if let d = entry.state.coverData, let ui = UIImage(data: d) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        } else {
            LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: size * 0.38))
                )
        }
    }
}

// MARK: - Medium Widget (рабочий стол, средний)

struct PlayerWidgetMediumView: View {
    let entry: PlayerEntry

    var body: some View {
        ZStack {
            // Фон
            if let d = entry.state.coverData, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 22)
                    .overlay(Color.black.opacity(0.62))
            } else {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.04, blue: 0.18),
                             Color(red: 0.04, green: 0.09, blue: 0.28)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            HStack(spacing: 14) {
                // Обложка
                coverThumbnail(size: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.5), radius: 8)

                VStack(alignment: .leading, spacing: 0) {
                    // Track info
                    Text(entry.state.trackTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(entry.state.artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                        .padding(.top, 3)

                    Spacer()

                    // Controls
                    controlButtons
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            HStack(spacing: 20) {
                Button(intent: SkipPreviousIntent()) {
                    Image(systemName: "backward.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 17))
                }
                .buttonStyle(.plain)

                Button(intent: TogglePlayPauseIntent()) {
                    Image(systemName: entry.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 34))
                        .shadow(color: .cyan.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)

                Button(intent: SkipNextIntent()) {
                    Image(systemName: "forward.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 17))
                }
                .buttonStyle(.plain)
            }
        } else {
            // iOS 16: кнопки не интерактивны, просто отображают состояние
            HStack(spacing: 20) {
                Image(systemName: "backward.fill").foregroundColor(.white).font(.system(size: 17))
                Image(systemName: entry.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(.white).font(.system(size: 34))
                Image(systemName: "forward.fill").foregroundColor(.white).font(.system(size: 17))
            }
        }
    }

    @ViewBuilder
    private func coverThumbnail(size: CGFloat) -> some View {
        if let d = entry.state.coverData, let ui = UIImage(data: d) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        } else {
            LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: size * 0.38))
                )
        }
    }
}

// MARK: - Lock Screen: Rectangular

struct PlayerWidgetLockRectView: View {
    let entry: PlayerEntry

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.state.trackTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(entry.state.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if #available(iOSApplicationExtension 17.0, *) {
                HStack(spacing: 10) {
                    Button(intent: SkipPreviousIntent()) {
                        Image(systemName: "backward.fill").font(.system(size: 13))
                    }.buttonStyle(.plain)

                    Button(intent: TogglePlayPauseIntent()) {
                        Image(systemName: entry.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                    }.buttonStyle(.plain)

                    Button(intent: SkipNextIntent()) {
                        Image(systemName: "forward.fill").font(.system(size: 13))
                    }.buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "backward.fill").font(.system(size: 13))
                    Image(systemName: entry.state.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 15))
                    Image(systemName: "forward.fill").font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Lock Screen: Circular

struct PlayerWidgetLockCircularView: View {
    let entry: PlayerEntry

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Button(intent: TogglePlayPauseIntent()) {
                Image(systemName: entry.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: entry.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .bold))
        }
    }
}

// MARK: - Entry View Router

struct PlayerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PlayerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            PlayerWidgetSmallView(entry: entry)
        case .systemMedium:
            PlayerWidgetMediumView(entry: entry)
        case .accessoryRectangular:
            PlayerWidgetLockRectView(entry: entry)
        case .accessoryCircular:
            PlayerWidgetLockCircularView(entry: entry)
        default:
            PlayerWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct PlayerWidget: Widget {
    let kind: String = "CloudMusicPlayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlayerProvider()) { entry in
            PlayerWidgetEntryView(entry: entry)
                // containerBackground требует iOS 17+; на iOS 16 виджет рисует фон сам
                .widgetBackground()
        }
        .configurationDisplayName("CloudMusicPlayer")
        .description("Управляй музыкой прямо с рабочего стола")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}


// MARK: - Compatibility Helper

extension View {
    /// Применяет containerBackground на iOS 17+, ничего не делает на iOS 16.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

// MARK: - Widget Bundle Entry Point

@main
struct PlayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlayerWidget()
    }
}

