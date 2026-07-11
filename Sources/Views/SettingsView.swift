import SwiftUI

/// Экран настроек приложения и авторизации
struct SettingsView: View {
    @ObservedObject var googleService = GoogleDriveService.shared
    @ObservedObject var yandexService = YandexDiskService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    
    // Переменные полей ввода
    @State private var googleClientID = ""
    @State private var googleAccessToken = ""
    @State private var yandexToken = ""
    
    @AppStorage("autoDownloadFavorites") private var autoDownloadFavorites = true
    
    // Статусы уведомлений
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фон
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Секция Google Диск
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "logo.googledrive")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                Text("Настройка Google Диска")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                if googleService.isAuthenticated {
                                    Text("Подключено")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                            
                            if googleService.isAuthenticated {
                                Text("Вы вошли в систему Google Drive. Приложение может скачивать аудиофайлы и воспроизводить их онлайн.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    googleService.logout()
                                    googleAccessToken = ""
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Выйти из Google аккаунта")
                                            .foregroundColor(.red)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Инструкция:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                    Text("1. Перейдите в Google Cloud Console и создайте проект.\n2. Включите API Google Drive.\n3. Создайте учетные данные OAuth (Client ID) и OAuth Token.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    TextField("Google Client ID", text: $googleClientID)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .preferredColorScheme(.dark)
                                    
                                    SecureField("OAuth Access Token", text: $googleAccessToken)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .preferredColorScheme(.dark)
                                    
                                    Button(action: {
                                        if googleClientID.isEmpty || googleAccessToken.isEmpty {
                                            alertMessage = "Пожалуйста, заполните все поля Google Drive"
                                            showingAlert = true
                                        } else {
                                            googleService.saveCredentials(clientID: googleClientID, accessToken: googleAccessToken)
                                            alertMessage = "Настройки Google Drive сохранены!"
                                            showingAlert = true
                                        }
                                    }) {
                                        HStack {
                                            Spacer()
                                            Text("Подключить Google Drive")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .background(Color.purple)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // 2. Секция Яндекс Диск
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "y.circle.fill")
                                    .foregroundColor(.cyan)
                                    .font(.title3)
                                Text("Настройка Яндекс Диска")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                if yandexService.isAuthenticated {
                                    Text("Подключено")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                            
                            if yandexService.isAuthenticated {
                                Text("Вы вошли в систему Яндекс.Диска. Вся музыка из папок диска доступна для прослушивания.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                
                                Button(action: {
                                    yandexService.logout()
                                    yandexToken = ""
                                }) {
                                    HStack {
                                        Spacer()
                                        Text("Выйти из Яндекс аккаунта")
                                            .foregroundColor(.red)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Инструкция:")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyan)
                                    Text("1. Перейдите на Яндекс.ID и создайте новое приложение.\n2. В правах доступа выберите 'Доступ к Яндекс.Диску (все папки)'.\n3. Получите отладочный токен и вставьте его ниже.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    SecureField("OAuth-токен Яндекса", text: $yandexToken)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .preferredColorScheme(.dark)
                                    
                                    Button(action: {
                                        if yandexToken.isEmpty {
                                            alertMessage = "Пожалуйста, введите токен Яндекс Диска"
                                            showingAlert = true
                                        } else {
                                            yandexService.saveToken(yandexToken)
                                            alertMessage = "Токен Яндекс Диска успешно сохранен!"
                                            showingAlert = true
                                        }
                                    }) {
                                        HStack {
                                            Spacer()
                                            Text("Подключить Яндекс Диск")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .background(Color.cyan)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // 3. Управление памятью и кэшем
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Управление хранилищем")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Все скачанные треки сохраняются на устройстве. При очистке кэша они будут удалены, а база оффлайн треков сбросится.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                // Очистка кэша
                                downloadManager.localTracks.forEach { track in
                                    downloadManager.deleteTrack(trackId: track.id)
                                }
                                alertMessage = "Медиатека успешно очищена!"
                                showingAlert = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Очистить оффлайн-медиатеку")
                                        .foregroundColor(.red)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // 4. Настройки загрузок
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Настройки загрузок")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Toggle(isOn: $autoDownloadFavorites) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Скачивать избранное автоматически")
                                        .foregroundColor(.white)
                                        .font(.system(size: 15))
                                    Text("Автоматически скачивать треки в медиатеку при добавлении в избранное.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            .tint(.purple)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // О приложении
                        VStack(spacing: 6) {
                            Text("Cloud Music Player v1.0.0")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text("iOS 16+ Native Music Player App\nDesign by Antigravity")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Настройки")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Информация"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                // Подгружаем существующие значения в форму
                googleClientID = googleService.getClientID() ?? ""
                googleAccessToken = googleService.getAccessToken() ?? ""
                yandexToken = yandexService.getToken() ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }
}
