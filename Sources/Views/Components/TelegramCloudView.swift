import SwiftUI

/// Экран работы с файлами и треками из Telegram во вкладке "Облако"
struct TelegramCloudView: View {
    @ObservedObject var telegramService = TelegramService.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    
    @State private var inputToken = ""
    @State private var searchText = ""
    @State private var showingTokenHelp = false
    
    var filteredTracks: [TelegramAudioTrack] {
        if searchText.isEmpty {
            return telegramService.tracks
        } else {
            return telegramService.tracks.filter { track in
                track.name.localizedCaseInsensitiveContains(searchText) ||
                (track.performer?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (track.chatTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !telegramService.isAuthenticated {
                authView
            } else {
                tracksView
            }
        }
    }
    
    // MARK: - Экран Авторизации через Telegram Bot API
    
    private var authView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                        .blur(radius: 10)
                    
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                VStack(spacing: 8) {
                    Text("Вход в Telegram Music")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Подключите ваш Telegram для прослушивания онлайн-музыки из всех ваших каналов и чатов.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bot API Token")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.cyan)
                        
                        SecureField("Введите токен бота (из @BotFather)", text: $inputToken)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                    
                    Button(action: { showingTokenHelp.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                            Text("Как получить токен за 10 секунд?")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 24)
                
                if let error = telegramService.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.pink)
                        .padding(.horizontal, 24)
                }
                
                Button(action: {
                    HapticManager.shared.triggerImpact(style: .medium)
                    telegramService.authenticate(token: inputToken) { _ in }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 52)
                        
                        if telegramService.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Войти и найти музыку")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(inputToken.isEmpty || telegramService.isLoading)
                .opacity(inputToken.isEmpty ? 0.6 : 1.0)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingTokenHelp) {
            tokenHelpSheet
        }
    }
    
    // MARK: - Экран списка треков из Telegram
    
    private var tracksView: some View {
        VStack(spacing: 14) {
            // Панель статуса аккаунта
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.cyan)
                    Text(telegramService.botUsername)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.triggerSelection()
                    telegramService.fetchAudioTracks()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cyan)
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Circle().fill(Color.cyan.opacity(0.12)))
                }
                
                Button(action: {
                    telegramService.logout()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.pink)
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Circle().fill(Color.pink.opacity(0.12)))
                }
            }
            .padding(.horizontal, 20)
            
            // Поиск
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Поиск музыки из Telegram...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            if telegramService.isLoading {
                VStack(spacing: 12) {
                    Spacer().frame(height: 30)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    Text("Сканирование треков из Telegram...")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            } else if filteredTracks.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Треки не найдены")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Отправьте любой аудиофайл или музыку вашему боту или перешлите её в диалог с ботом, затем нажмите кнопку обновить.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredTracks) { track in
                            telegramTrackRow(track: track)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func telegramTrackRow(track: TelegramAudioTrack) -> some View {
        let isPlayingThis = playerManager.currentTrack?.id == "tg_\(track.id)"
        
        return HStack(spacing: 12) {
            Button(action: {
                playTelegramTrack(track)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isPlayingThis && playerManager.playbackState == .playing ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isPlayingThis ? .cyan : .white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(track.chatTitle ?? "Telegram")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(1)
                    
                    if let duration = track.duration {
                        Text("• \(formatTime(Double(duration)))")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(isPlayingThis ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(14)
    }
    
    // MARK: - Helpers
    
    private func playTelegramTrack(_ track: TelegramAudioTrack) {
        HapticManager.shared.triggerImpact(style: .medium)
        
        Task {
            if let directUrl = await telegramService.getDirectStreamURL(for: track.fileId) {
                await MainActor.run {
                    let playerTrack = PlayerTrack(
                        id: "tg_\(track.id)",
                        title: track.displayName,
                        artist: track.performer ?? (track.chatTitle ?? "Telegram"),
                        sourceName: "Telegram",
                        localURL: nil,
                        remoteURL: directUrl,
                        googleFileId: nil,
                        localCoverURL: nil,
                        duration: track.duration.map { Double($0) }
                    )
                    playerManager.play(track: playerTrack, in: [playerTrack])
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var tokenHelpSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Инструкция по получению токена:")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Откройте Telegram и найдите официального бота **@BotFather**.")
                    Text("2. Нажмите /start и затем отправьте команду **/newbot**.")
                    Text("3. Введите название и имя вашего бота (например, `MyMusicBot`).")
                    Text("4. Бот пришлёт вам токен вида: `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`.")
                    Text("5. Вставьте этот токен в приложение — готово!")
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Токен Telegram")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}
