import Foundation
import Combine
import AVFoundation

/// Модель аудиофайла из Telegram
struct TelegramAudioTrack: Identifiable, Codable, Equatable {
    let id: String // file_unique_id or file_id
    let fileId: String
    let name: String
    let performer: String?
    let duration: Int?
    let fileSize: Int64?
    let mimeType: String?
    let chatId: Int64?
    let chatTitle: String?
    
    var displayName: String {
        if let performer = performer, !performer.isEmpty {
            return "\(performer) — \(name)"
        }
        return name
    }
}

/// Сервис взаимодействия с Telegram Bot API (сканирование чатов, каналов и Избранного на наличие аудиофайлов)
final class TelegramService: ObservableObject {
    static let shared = TelegramService()
    
    @Published var botToken: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var botUsername: String = ""
    @Published var tracks: [TelegramAudioTrack] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let tokenKey = "com.samvel.cloudmusicplayer.telegramBotToken"
    private let botNameKey = "com.samvel.cloudmusicplayer.telegramBotName"
    private let tracksCacheKey = "com.samvel.cloudmusicplayer.telegramTracks"
    
    private init() {
        loadSavedSession()
    }
    
    /// Сохранение сессии
    private func loadSavedSession() {
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey), !savedToken.isEmpty {
            self.botToken = savedToken
            self.botUsername = UserDefaults.standard.string(forKey: botNameKey) ?? "Telegram Bot"
            self.isAuthenticated = true
            loadCachedTracks()
            // Обновляем список треков в фоновом режиме
            fetchAudioTracks()
        }
    }
    
    /// Авторизация через Bot Token
    func authenticate(token: String, completion: @escaping (Bool) -> Void) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            self.errorMessage = "Введите токен бота Telegram"
            completion(false)
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        let urlStr = "https://api.telegram.org/bot\(cleanToken)/getMe"
        guard let url = URL(string: urlStr) else {
            self.isLoading = false
            self.errorMessage = "Некорректный URL запроса"
            completion(false)
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Неверный токен бота Telegram"
                        completion(false)
                    }
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = json["ok"] as? Bool, ok,
                   let result = json["result"] as? [String: Any],
                   let username = result["username"] as? String {
                    
                    await MainActor.run {
                        self.botToken = cleanToken
                        self.botUsername = "@\(username)"
                        self.isAuthenticated = true
                        self.isLoading = false
                        
                        UserDefaults.standard.set(cleanToken, forKey: self.tokenKey)
                        UserDefaults.standard.set(self.botUsername, forKey: self.botNameKey)
                        
                        self.fetchAudioTracks()
                        completion(true)
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Ошибка ответа Telegram API"
                        completion(false)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    /// Выход из аккаунта
    func logout() {
        botToken = ""
        botUsername = ""
        isAuthenticated = false
        tracks = []
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: botNameKey)
        UserDefaults.standard.removeObject(forKey: tracksCacheKey)
    }
    
    /// Сканирование сообщений и всех входящих аудиозаписей
    func fetchAudioTracks() {
        guard isAuthenticated, !botToken.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        let urlStr = "https://api.telegram.org/bot\(botToken)/getUpdates?allowed_updates=[\"message\",\"channel_post\"]"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                
                var foundTracks: [TelegramAudioTrack] = []
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultList = json["result"] as? [[String: Any]] {
                    
                    for item in resultList {
                        let msg = (item["message"] as? [String: Any]) ?? (item["channel_post"] as? [String: Any])
                        guard let message = msg else { continue }
                        
                        let chat = message["chat"] as? [String: Any]
                        let chatId = chat?["id"] as? Int64
                        let chatTitle = (chat?["title"] as? String) ?? (chat?["first_name"] as? String) ?? "Telegram Chat"
                        
                        // 1. Проверяем аудио (музыка)
                        if let audio = message["audio"] as? [String: Any],
                           let fileId = audio["file_id"] as? String {
                            let uniqueId = (audio["file_unique_id"] as? String) ?? fileId
                            let title = (audio["title"] as? String) ?? (audio["file_name"] as? String) ?? "Telegram Audio Track"
                            let performer = audio["performer"] as? String
                            let duration = audio["duration"] as? Int
                            let fileSize = (audio["file_size"] as? Int64) ?? (audio["file_size"] as? Int).map { Int64($0) }
                            let mimeType = audio["mime_type"] as? String
                            
                            let track = TelegramAudioTrack(
                                id: uniqueId,
                                fileId: fileId,
                                name: title,
                                performer: performer,
                                duration: duration,
                                fileSize: fileSize,
                                mimeType: mimeType,
                                chatId: chatId,
                                chatTitle: chatTitle
                            )
                            foundTracks.append(track)
                        }
                        
                        // 2. Проверяем документы (если отправлено файлом)
                        else if let doc = message["document"] as? [String: Any],
                                let fileId = doc["file_id"] as? String {
                            let mime = doc["mime_type"] as? String ?? ""
                            let name = (doc["file_name"] as? String) ?? "Audio File"
                            let ext = (name as NSString).pathExtension.lowercased()
                            
                            if mime.contains("audio") || ["mp3", "m4a", "flac", "wav", "aac", "ogg"].contains(ext) {
                                let uniqueId = (doc["file_unique_id"] as? String) ?? fileId
                                let fileSize = (doc["file_size"] as? Int64) ?? (doc["file_size"] as? Int).map { Int64($0) }
                                
                                let track = TelegramAudioTrack(
                                    id: uniqueId,
                                    fileId: fileId,
                                    name: name,
                                    performer: "Telegram Document",
                                    duration: nil,
                                    fileSize: fileSize,
                                    mimeType: mime,
                                    chatId: chatId,
                                    chatTitle: chatTitle
                                )
                                foundTracks.append(track)
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    // Исключаем дубликаты по uniqueId
                    var seen = Set<String>()
                    let uniqueTracks = foundTracks.filter { seen.insert($0.id).inserted }
                    
                    self.tracks = uniqueTracks
                    self.isLoading = false
                    self.saveCachedTracks()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Получение прямой стриминговой ссылки на аудиофайл через Telegram API
    func getDirectStreamURL(for fileId: String) async -> URL? {
        guard !botToken.isEmpty else { return nil }
        
        let getFileUrlStr = "https://api.telegram.org/bot\(botToken)/getFile?file_id=\(fileId)"
        guard let url = URL(string: getFileUrlStr) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok,
               let result = json["result"] as? [String: Any],
               let filePath = result["file_path"] as? String {
                
                let streamUrlStr = "https://api.telegram.org/file/bot\(botToken)/\(filePath)"
                return URL(string: streamUrlStr)
            }
        } catch {
            print("TelegramService: Ошибка получения файла: \(error)")
        }
        return nil
    }
    
    private func saveCachedTracks() {
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: tracksCacheKey)
        }
    }
    
    private func loadCachedTracks() {
        if let data = UserDefaults.standard.data(forKey: tracksCacheKey),
           let cached = try? JSONDecoder().decode([TelegramAudioTrack].self, from: data) {
            self.tracks = cached
        }
    }
}
