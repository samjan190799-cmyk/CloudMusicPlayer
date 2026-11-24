import SwiftUI

/// Вкладка «Облако»: подключённые источники, музыка на iPhone и загрузки
struct CloudHubView: View {
    @ObservedObject private var google = GoogleDriveService.shared
    @ObservedObject private var yandex = YandexDiskService.shared
    @ObservedObject private var telegram = TelegramService.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var scanner = DeviceMediaScanner.shared

    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Облачные хранилища")
                        VStack(spacing: 10) {
                            NavigationLink {
                                CloudDriveView(provider: .google)
                            } label: {
                                SourceCard(
                                    title: "Google Диск",
                                    subtitle: google.isAuthenticated ? Formatters.tracks(google.tracks.count) : "Не подключён",
                                    icon: "externaldrive.fill",
                                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.13, green: 0.66, blue: 0.33)],
                                    isConnected: google.isAuthenticated
                                )
                            }
                            NavigationLink {
                                CloudDriveView(provider: .yandex)
                            } label: {
                                SourceCard(
                                    title: "Яндекс Диск",
                                    subtitle: yandex.isAuthenticated ? Formatters.tracks(yandex.tracks.count) : "Не подключён",
                                    icon: "y.circle.fill",
                                    colors: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 0.98, green: 0.24, blue: 0.2)],
                                    isConnected: yandex.isAuthenticated
                                )
                            }
                            NavigationLink {
                                TelegramSourceView()
                            } label: {
                                SourceCard(
                                    title: "Telegram",
                                    subtitle: telegram.isAuthenticated
                                        ? "\(telegram.botUsername) · \(Formatters.tracks(telegram.tracks.count))"
                                        : "Не подключён",
                                    icon: "paperplane.fill",
                                    colors: [Color(red: 0.16, green: 0.67, blue: 0.96), Color(red: 0.1, green: 0.4, blue: 0.85)],
                                    isConnected: telegram.isAuthenticated
                                )
                            }
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                        .padding(.horizontal, Metrics.screenPadding)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "На этом iPhone")
                        VStack(spacing: 10) {
                            Button {
                                showImporter = true
                            } label: {
                                SourceCard(
                                    title: "Импорт из «Файлов»",
                                    subtitle: "MP3, M4A, FLAC, WAV, OGG, OPUS",
                                    icon: "square.and.arrow.down.fill",
                                    colors: [Color(red: 0.55, green: 0.47, blue: 1.0), Color(red: 0.3, green: 0.18, blue: 0.7)],
                                    isConnected: nil
                                )
                            }
                            Button {
                                scanner.requestAndScanAppleMusic()
                                AppRouter.shared.showToast("Ищем музыку на iPhone…", icon: "iphone")
                            } label: {
                                SourceCard(
                                    title: "Музыка iPhone",
                                    subtitle: scanner.isAppleMusicAuthorized
                                        ? Formatters.tracks(scanner.deviceTracks.count)
                                        : "Песни из приложения «Музыка» без DRM",
                                    icon: "music.note",
                                    colors: [Color(red: 1.0, green: 0.3, blue: 0.4), Color(red: 0.7, green: 0.1, blue: 0.3)],
                                    isConnected: scanner.isAppleMusicAuthorized ? true : nil
                                )
                            }
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                        .padding(.horizontal, Metrics.screenPadding)

                        Text("Музыку можно положить и вручную: «Файлы» → «На iPhone» → CloudPlayer. Она появится в медиатеке автоматически.")
                            .font(.appCaption)
                            .foregroundColor(Palette.textTertiary)
                            .padding(.horizontal, Metrics.screenPadding)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Загрузки")
                        NavigationLink {
                            DownloadsView()
                        } label: {
                            SourceCard(
                                title: "Скачанное",
                                subtitle: downloadsSubtitle,
                                icon: "arrow.down.circle.fill",
                                colors: [Color(red: 0.2, green: 0.82, blue: 0.62), Color(red: 0.04, green: 0.3, blue: 0.35)],
                                isConnected: nil
                            )
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                        .padding(.horizontal, Metrics.screenPadding)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .hiddenNavigationBar()
            .sheet(isPresented: $showImporter) {
                AudioDocumentPicker { urls in
                    DeviceMediaScanner.shared.importFiles(from: urls)
                    AppRouter.shared.showToast("Импортируем \(Formatters.tracks(urls.count))", icon: "square.and.arrow.down.fill")
                }
                .ignoresSafeArea()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Облако")
                    .font(.appLargeTitle)
                    .foregroundColor(Palette.textPrimary)
                Text("Вся ваша музыка в одном месте")
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            CircleIconButton(systemName: "gearshape.fill", size: 40, iconSize: 17) {
                AppRouter.shared.isSettingsPresented = true
            }
            .accessibilityLabel("Настройки")
        }
        .padding(.horizontal, Metrics.screenPadding)
    }

    private var downloadsSubtitle: String {
        let size = downloads.localTracks.reduce(Int64(0)) { $0 + $1.size }
        var text = "\(Formatters.tracks(downloads.localTracks.count)) · \(Formatters.bytes(size))"
        if !downloads.activeDownloads.isEmpty {
            text = "Загружается: \(downloads.activeDownloads.count) · " + text
        }
        return text
    }
}

// MARK: - Карточка источника

struct SourceCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    /// true — подключено, false — нет, nil — статус не показывается
    let isConnected: Bool?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appRowTitle)
                    .foregroundColor(Palette.textPrimary)
                Text(subtitle)
                    .font(.appSubheadline)
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let isConnected = isConnected {
                Circle()
                    .fill(isConnected ? Palette.success : Palette.textTertiary)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.textTertiary)
        }
        .padding(12)
        .cardBackground(cornerRadius: 16)
    }
}
