import SwiftUI

// MARK: - Поле ввода в стиле приложения

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: Text(title).foregroundColor(Palette.textTertiary))
            } else {
                TextField("", text: $text, prompt: Text(title).foregroundColor(Palette.textTertiary))
            }
        }
        .font(.appBody)
        .foregroundColor(Palette.textPrimary)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surfaceStrong)
        )
    }
}

/// Пронумерованные шаги инструкции
struct InstructionSteps: View {
    let steps: [String]
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(accent))
                    Text(step)
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Google Диск

struct GoogleConnectForm: View {
    @ObservedObject private var service = GoogleDriveService.shared
    @State private var clientID = ""
    @State private var accessToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstructionSteps(steps: [
                "Откройте Google Cloud Console и создайте проект.",
                "Включите Google Drive API.",
                "Создайте OAuth Client ID и получите access token (например, через OAuth Playground)."
            ])

            AppTextField(title: "Google Client ID", text: $clientID)
            AppTextField(title: "OAuth Access Token", text: $accessToken, isSecure: true)

            Button("Подключить Google Диск") {
                let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
                let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty, !token.isEmpty else {
                    AppRouter.shared.showToast("Заполните оба поля", icon: "exclamationmark.circle.fill")
                    return
                }
                service.saveCredentials(clientID: id, accessToken: token)
                service.fetchAudioFiles()
                HapticManager.shared.triggerNotification(type: .success)
                AppRouter.shared.showToast("Google Диск подключён", icon: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())

            Text("Токен Google действует около часа. Если список перестанет загружаться, вставьте новый токен.")
                .font(.appCaption)
                .foregroundColor(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            clientID = service.getClientID() ?? ""
        }
    }
}

// MARK: - Яндекс Диск

struct YandexConnectForm: View {
    @ObservedObject private var service = YandexDiskService.shared
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstructionSteps(steps: [
                "Откройте oauth.yandex.ru и создайте приложение.",
                "В правах доступа выберите «Яндекс.Диск REST API» (чтение всего диска).",
                "Получите отладочный OAuth-токен и вставьте его ниже."
            ])

            AppTextField(title: "OAuth-токен Яндекса", text: $token, isSecure: true)

            Button("Подключить Яндекс Диск") {
                let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    AppRouter.shared.showToast("Вставьте токен", icon: "exclamationmark.circle.fill")
                    return
                }
                service.saveToken(value)
                service.fetchAudioFiles()
                HapticManager.shared.triggerNotification(type: .success)
                AppRouter.shared.showToast("Яндекс Диск подключён", icon: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
        }
    }
}

// MARK: - Telegram

struct TelegramConnectForm: View {
    @ObservedObject private var service = TelegramService.shared
    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstructionSteps(steps: [
                "Откройте @BotFather в Telegram и отправьте /newbot.",
                "Придумайте имя — BotFather пришлёт токен вида 123456:ABC…",
                "Вставьте токен ниже, затем отправляйте или пересылайте боту аудио — оно появится здесь."
            ])

            AppTextField(title: "Токен бота", text: $token, isSecure: true)

            if let error = service.errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(Palette.danger)
            }

            Button {
                service.authenticate(token: token) { success in
                    if success {
                        HapticManager.shared.triggerNotification(type: .success)
                        AppRouter.shared.showToast("Telegram подключён", icon: "checkmark.circle.fill")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if service.isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text("Подключить бота")
                }
            }
            .buttonStyle(PrimaryCapsuleButtonStyle())
            .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || service.isLoading)

            Text("Бот видит только то, что вы отправили ему сами или переслали в чат с ним, а также посты каналов, где он администратор.")
                .font(.appCaption)
                .foregroundColor(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Экран подключения (для настроек)

struct ConnectionDetailView: View {
    let provider: CloudProvider

    @ObservedObject private var google = GoogleDriveService.shared
    @ObservedObject private var yandex = YandexDiskService.shared
    @ObservedObject private var telegram = TelegramService.shared

    @State private var showDisconnect = false

    private var isConnected: Bool {
        switch provider {
        case .google: return google.isAuthenticated
        case .yandex: return yandex.isAuthenticated
        case .telegram: return telegram.isAuthenticated
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isConnected {
                    connectedCard
                } else {
                    switch provider {
                    case .google:
                        GoogleConnectForm()
                    case .yandex:
                        YandexConnectForm()
                    case .telegram:
                        TelegramConnectForm()
                    }
                }
            }
            .padding(Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .background(Palette.backgroundRaised.ignoresSafeArea())
        .appNavigationBar(title: provider.title)
        .confirmationDialog("Отключить \(provider.title)?", isPresented: $showDisconnect, titleVisibility: .visible) {
            Button("Отключить", role: .destructive) {
                disconnect()
            }
        } message: {
            Text("Скачанные треки останутся на устройстве.")
        }
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Palette.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Подключено")
                        .font(.appHeadline)
                        .foregroundColor(Palette.textPrimary)
                    Text(connectedSubtitle)
                        .font(.appSubheadline)
                        .foregroundColor(Palette.textSecondary)
                }
            }
            Button("Отключить") {
                showDisconnect = true
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())
        }
        .padding(16)
        .cardBackground()
    }

    private var connectedSubtitle: String {
        switch provider {
        case .google: return "Найдено: \(Formatters.tracks(google.tracks.count))"
        case .yandex: return "Найдено: \(Formatters.tracks(yandex.tracks.count))"
        case .telegram: return "\(telegram.botUsername) · \(Formatters.tracks(telegram.tracks.count))"
        }
    }

    private func disconnect() {
        switch provider {
        case .google: google.logout()
        case .yandex: yandex.logout()
        case .telegram: telegram.logout()
        }
        AppRouter.shared.showToast("\(provider.title) отключён", icon: "xmark.circle.fill")
    }
}
