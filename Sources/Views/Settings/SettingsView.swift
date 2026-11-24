import SwiftUI

/// Настройки: оформление, воспроизведение, подключения, ИИ и хранилище
struct SettingsView: View {
    @ObservedObject private var google = GoogleDriveService.shared
    @ObservedObject private var yandex = YandexDiskService.shared
    @ObservedObject private var telegram = TelegramService.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var history = ListeningHistory.shared

    @AppStorage(AccentTheme.storageKey) private var accentRaw = AccentTheme.coral.rawValue
    @AppStorage("dynamicPlayerColor") private var dynamicPlayerColor = true
    @AppStorage("autoDownloadFavorites") private var autoDownloadFavorites = true
    @AppStorage("selectedAIProvider") private var selectedAIProvider = "gemini"
    @AppStorage("geminiApiKey") private var geminiApiKey = ""
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("anthropicApiKey") private var anthropicApiKey = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    @State private var showClearDownloads = false
    @State private var showClearHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    appearanceSection
                    playbackSection
                    connectionsSection
                    aiSection
                    storageSection
                    aboutSection
                }
                .padding(Metrics.screenPadding)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.backgroundRaised.ignoresSafeArea())
            .navigationTitle("Настройки")
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
            .confirmationDialog("Удалить всю скачанную музыку?", isPresented: $showClearDownloads, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    let ids = downloads.localTracks.map { $0.id }
                    ids.forEach { downloads.deleteTrack(trackId: $0) }
                    AppRouter.shared.showToast("Скачанное удалено", icon: "trash.fill")
                }
            } message: {
                Text("Плейлисты и избранное сохранятся, но треки придётся скачать заново.")
            }
            .confirmationDialog("Очистить историю прослушиваний?", isPresented: $showClearHistory, titleVisibility: .visible) {
                Button("Очистить", role: .destructive) {
                    history.clear()
                }
            } message: {
                Text("Разделы «Продолжить слушать» и «Часто слушаете» начнутся заново.")
            }
        }
    }

    // MARK: - Оформление

    private var appearanceSection: some View {
        SettingsGroup(title: "Оформление") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Акцентный цвет")
                    .font(.appRowTitle)
                    .foregroundColor(Palette.textPrimary)
                HStack(spacing: 0) {
                    ForEach(AccentTheme.allCases) { theme in
                        Button {
                            HapticManager.shared.triggerSelection()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                accentRaw = theme.rawValue
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 34, height: 34)
                                    if accentRaw == theme.rawValue {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2.5)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .heavy))
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                Text(theme.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(accentRaw == theme.rawValue ? Palette.textPrimary : Palette.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.9))
                        .accessibilityLabel(theme.title)
                    }
                }
            }
            .padding(.vertical, 4)

            SettingsDivider()

            Toggle(isOn: $dynamicPlayerColor) {
                SettingsLabel(
                    title: "Цвет плеера из обложки",
                    subtitle: "Плеер окрашивается в цвета текущего трека"
                )
            }
        }
    }

    // MARK: - Воспроизведение

    private var playbackSection: some View {
        SettingsGroup(title: "Воспроизведение") {
            Toggle(isOn: $autoDownloadFavorites) {
                SettingsLabel(
                    title: "Скачивать избранное",
                    subtitle: "Треки с ♥ автоматически сохраняются для офлайна"
                )
            }
            SettingsDivider()
            Button {
                showClearHistory = true
            } label: {
                SettingsNavigationRow(
                    title: "Очистить историю",
                    subtitle: "Записей: \(history.entries.count)",
                    icon: "clock.arrow.circlepath"
                )
            }
            .buttonStyle(.plain)
            .disabled(history.entries.isEmpty)
        }
    }

    // MARK: - Подключения

    private var connectionsSection: some View {
        SettingsGroup(title: "Подключения") {
            NavigationLink {
                ConnectionDetailView(provider: .google)
            } label: {
                SettingsNavigationRow(
                    title: "Google Диск",
                    subtitle: google.isAuthenticated ? "Подключён" : "Не подключён",
                    icon: "externaldrive.fill",
                    isConnected: google.isAuthenticated
                )
            }
            SettingsDivider()
            NavigationLink {
                ConnectionDetailView(provider: .yandex)
            } label: {
                SettingsNavigationRow(
                    title: "Яндекс Диск",
                    subtitle: yandex.isAuthenticated ? "Подключён" : "Не подключён",
                    icon: "y.circle.fill",
                    isConnected: yandex.isAuthenticated
                )
            }
            SettingsDivider()
            NavigationLink {
                ConnectionDetailView(provider: .telegram)
            } label: {
                SettingsNavigationRow(
                    title: "Telegram",
                    subtitle: telegram.isAuthenticated ? telegram.botUsername : "Не подключён",
                    icon: "paperplane.fill",
                    isConnected: telegram.isAuthenticated
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - ИИ

    private var aiSection: some View {
        SettingsGroup(
            title: "Умные названия (ИИ)",
            footer: "ИИ очищает названия скачанных с YouTube треков («Official Video», лишние слова) и подбирает исполнителя. Ключ хранится только на устройстве."
        ) {
            Picker("Провайдер", selection: $selectedAIProvider) {
                Text("Gemini").tag("gemini")
                Text("ChatGPT").tag("chatgpt")
                Text("Claude").tag("claude")
            }
            .pickerStyle(.segmented)

            switch selectedAIProvider {
            case "chatgpt":
                AppTextField(title: "OpenAI API Key", text: $openaiApiKey, isSecure: true)
            case "claude":
                AppTextField(title: "Anthropic API Key", text: $anthropicApiKey, isSecure: true)
            default:
                AppTextField(title: "Gemini API Key", text: $geminiApiKey, isSecure: true)
            }
        }
    }

    // MARK: - Хранилище

    private var storageSection: some View {
        let size = downloads.localTracks.reduce(Int64(0)) { $0 + $1.size }

        return SettingsGroup(title: "Хранилище") {
            HStack {
                SettingsLabel(
                    title: "Скачанная музыка",
                    subtitle: "\(Formatters.tracks(downloads.localTracks.count)) · \(Formatters.bytes(size))"
                )
                Spacer()
            }
            SettingsDivider()
            Button {
                showClearDownloads = true
            } label: {
                HStack {
                    Text("Удалить всё скачанное")
                        .font(.appRowTitle)
                        .foregroundColor(Palette.danger)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(downloads.localTracks.isEmpty)
            .opacity(downloads.localTracks.isEmpty ? 0.4 : 1)
        }
    }

    // MARK: - О приложении

    private var aboutSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(accent)
            Text("CloudPlayer \(appVersion)")
                .font(.appHeadline)
                .foregroundColor(Palette.textPrimary)
            Text("Ваша музыка из облака, YouTube и «Файлов» — без подписок")
                .font(.appCaption)
                .foregroundColor(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

// MARK: - Компоненты настроек

struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String? = nil
    let content: Content

    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Palette.textTertiary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .cardBackground()

            if let footer = footer {
                Text(footer)
                    .font(.appCaption)
                    .foregroundColor(Palette.textTertiary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsLabel: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appRowTitle)
                .foregroundColor(Palette.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var isConnected: Bool? = nil

    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent.opacity(0.15)))
            SettingsLabel(title: title, subtitle: subtitle)
            Spacer()
            if let isConnected = isConnected {
                Circle()
                    .fill(isConnected ? Palette.success : Palette.textTertiary)
                    .frame(width: 8, height: 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.textTertiary)
        }
        .contentShape(Rectangle())
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 1)
    }
}
