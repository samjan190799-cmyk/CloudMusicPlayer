import Foundation

/// Модель трека из Google Диска
struct GoogleTrack: Identifiable, Codable {
    let id: String
    let name: String
    let mimeType: String
    let size: String?
    
    var sizeInBytes: Int64 {
        Int64(size ?? "0") ?? 0
    }
}

/// Сервис для работы с Google Drive API v3
class GoogleDriveService: ObservableObject {
    static let shared = GoogleDriveService()
    
    @Published var isAuthenticated = false
    @Published var tracks: [GoogleTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let clientIDKey = "GoogleDriveClientID"
    private let accessTokenKey = "GoogleDriveAccessToken"
    
    init() {
        // Проверяем наличие токена при инициализации
        if let token = getAccessToken(), !token.isEmpty {
            self.isAuthenticated = true
        }
    }
    
    /// Сохранение учетных данных
    func saveCredentials(clientID: String, accessToken: String) {
        UserDefaults.standard.set(clientID, forKey: clientIDKey)
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        self.isAuthenticated = !accessToken.isEmpty
        objectWillChange.send()
    }
    
    /// Получение сохраненного токена доступа
    func getAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    /// Получение сохраненного Client ID
    func getClientID() -> String? {
        return UserDefaults.standard.string(forKey: clientIDKey)
    }
    
    /// Выход из аккаунта
    func logout() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: clientIDKey)
        self.isAuthenticated = false
        self.tracks = []
    }
    
    /// Загрузка списка аудиофайлов с Google Drive
    func fetchAudioFiles() {
        guard let token = getAccessToken() else {
            self.errorMessage = "Отсутствует токен доступа Google Drive"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        // Поиск файлов с mimeType, содержащим 'audio/'
        let query = "mimeType contains 'audio/' and trashed = false"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            self.isLoading = false
            self.errorMessage = "Ошибка кодирования запроса"
            return
        }
        
        let urlString = "https://www.googleapis.com/drive/v3/files?q=\(encodedQuery)&fields=files(id,name,mimeType,size)"
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.errorMessage = "Неверный URL API"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка сети: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "Неизвестный ответ сервера"
                    return
                }
                
                if httpResponse.statusCode == 401 {
                    self?.errorMessage = "Токен доступа устарел или недействителен"
                    self?.isAuthenticated = false
                    return
                }
                
                guard httpResponse.statusCode == 200, let data = data else {
                    self?.errorMessage = "Ошибка сервера: код \(httpResponse.statusCode)"
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GoogleDriveFilesResponse.self, from: data)
                    self?.tracks = result.files
                } catch {
                    self?.errorMessage = "Ошибка декодирования данных: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Создание запроса для скачивания файла (используется плеером и менеджером загрузок)
    func makeDownloadRequest(forFileId fileId: String) -> URLRequest? {
        let urlString = "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media"
        guard let url = URL(string: urlString), let token = getAccessToken() else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

// Вспомогательная структура для парсинга ответа Google Drive API
struct GoogleDriveFilesResponse: Codable {
    let files: [GoogleTrack]
}
