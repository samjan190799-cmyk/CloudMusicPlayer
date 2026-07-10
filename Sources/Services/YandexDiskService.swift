import Foundation

/// Модель трека из Яндекс Диска
struct YandexTrack: Identifiable, Codable {
    let id: String // Путь к файлу на Диске служит ID
    let name: String
    let path: String
    let size: Int64?
    let mimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, size
        case id = "resource_id"
        case mimeType = "mime_type"
    }
}

/// Сервис для работы с API Яндекс Диска
class YandexDiskService: ObservableObject {
    static let shared = YandexDiskService()
    
    @Published var isAuthenticated = false
    @Published var tracks: [YandexTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let tokenKey = "YandexDiskToken"
    
    init() {
        if let token = getToken(), !token.isEmpty {
            self.isAuthenticated = true
        }
    }
    
    /// Сохранение токена
    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        self.isAuthenticated = !token.isEmpty
        objectWillChange.send()
    }
    
    /// Получение сохраненного токена
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    /// Выход из аккаунта
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        self.isAuthenticated = false
        self.tracks = []
    }
    
    /// Загрузка списка аудиофайлов
    func fetchAudioFiles() {
        guard let token = getToken() else {
            self.errorMessage = "Отсутствует токен Яндекс Диска"
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        // Яндекс API позволяет получить все аудиофайлы плоским списком
        let urlString = "https://cloud-api.yandex.net/v1/disk/resources/files?media_type=audio&limit=100"
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.errorMessage = "Неверный URL API"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
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
                    self?.errorMessage = "Токен авторизации Яндекс Диска недействителен"
                    self?.isAuthenticated = false
                    return
                }
                
                guard httpResponse.statusCode == 200, let data = data else {
                    self?.errorMessage = "Ошибка сервера Яндекс: код \(httpResponse.statusCode)"
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(YandexFilesResponse.self, from: data)
                    // У некоторых файлов может отсутствовать resource_id, сгенерируем на основе пути
                    self?.tracks = result.items.map { item in
                        if item.id.isEmpty {
                            return YandexTrack(id: item.path, name: item.name, path: item.path, size: item.size, mimeType: item.mimeType)
                        }
                        return item
                    }
                } catch {
                    self?.errorMessage = "Ошибка декодирования данных: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Получение временной прямой ссылки на скачивание/стриминг файла
    func getDownloadUrl(forPath path: String, completion: @escaping (URL?) -> Void) {
        guard let token = getToken() else {
            completion(nil)
            return
        }
        
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }
        
        let urlString = "https://cloud-api.yandex.net/v1/disk/resources/download?path=\(encodedPath)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                let downloadInfo = try JSONDecoder().decode(YandexDownloadInfo.self, from: data)
                if let downloadUrl = URL(string: downloadInfo.href) {
                    completion(downloadUrl)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

// Вспомогательные структуры
struct YandexFilesResponse: Codable {
    let items: [YandexTrack]
}

struct YandexDownloadInfo: Codable {
    let href: String
    let method: String
}
