import Foundation

enum AIProvider: String, CaseIterable {
    case gemini
    case chatgpt
    case claude
    
    var displayName: String {
        switch self {
        case .gemini: return "Gemini 3.5 Flash"
        case .chatgpt: return "GPT-5"
        case .claude: return "Claude 5 Sonnet"
        }
    }
}

/// Сервис интеграции ИИ для обработки названий и метаданных
class AIService {
    static let shared = AIService()
    private init() {}
    
    /// Очистка метаданных грязного заголовка YouTube
    func cleanMetadata(rawTitle: String, completion: @escaping (String?, String?) -> Void) {
        let providerRaw = UserDefaults.standard.string(forKey: "selectedAIProvider") ?? AIProvider.gemini.rawValue
        let provider = AIProvider(rawValue: providerRaw) ?? .gemini
        
        switch provider {
        case .gemini:
            cleanWithGemini(rawTitle: rawTitle, completion: completion)
        case .chatgpt:
            cleanWithChatGPT(rawTitle: rawTitle, completion: completion)
        case .claude:
            cleanWithClaude(rawTitle: rawTitle, completion: completion)
        }
    }
    
    private func cleanWithGemini(rawTitle: String, completion: @escaping (String?, String?) -> Void) {
        let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
        guard !apiKey.isEmpty else {
            completion(nil, nil)
            return
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        let prompt = "Analyze this music video title: \"\(rawTitle)\". Extract the clean song title and the main artist name. Respond ONLY with a valid JSON in this exact format: {\"title\": \"Song Title\", \"artist\": \"Artist Name\"}. Do not include markdown code formatting, backticks, or any other text."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil)
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, nil)
                return
            }
            
            self.parseJSONResponse(data: data, path: ["candidates", 0, "content", "parts", 0, "text"], completion: completion)
        }.resume()
    }
    
    private func cleanWithChatGPT(rawTitle: String, completion: @escaping (String?, String?) -> Void) {
        let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        guard !apiKey.isEmpty else {
            completion(nil, nil)
            return
        }
        
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        let prompt = "Extract the clean song title and the main artist name from this title: \"\(rawTitle)\". Return JSON with keys 'title' and 'artist'."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-5",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil)
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, nil)
                return
            }
            
            self.parseJSONResponse(data: data, path: ["choices", 0, "message", "content"], completion: completion)
        }.resume()
    }
    
    private func cleanWithClaude(rawTitle: String, completion: @escaping (String?, String?) -> Void) {
        let apiKey = UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
        guard !apiKey.isEmpty else {
            completion(nil, nil)
            return
        }
        
        let urlString = "https://api.anthropic.com/v1/messages"
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        let prompt = "Analyze this music video title: \"\(rawTitle)\". Extract the clean song title and the main artist name. Respond ONLY with a valid JSON in this exact format: {\"title\": \"Song Title\", \"artist\": \"Artist Name\"}. Do not include markdown code formatting, backticks, or any other text."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-5-sonnet",
            "max_tokens": 150,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil)
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, nil)
                return
            }
            
            self.parseJSONResponse(data: data, path: ["content", 0, "text"], completion: completion)
        }.resume()
    }
    
    private func parseJSONResponse(data: Data, path: [Any], completion: @escaping (String?, String?) -> Void) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(nil, nil)
            return
        }
        
        var current: Any? = root
        for step in path {
            if let key = step as? String, let dict = current as? [String: Any] {
                current = dict[key]
            } else if let idx = step as? Int, let array = current as? [Any], idx < array.count {
                current = array[idx]
            } else {
                current = nil
                break
            }
        }
        
        guard let text = current as? String else {
            completion(nil, nil)
            return
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let cleanData = cleanText.data(using: .utf8),
           let result = try? JSONSerialization.jsonObject(with: cleanData) as? [String: String] {
            let title = result["title"]
            let artist = result["artist"]
            completion(title, artist)
        } else {
            completion(nil, nil)
        }
    }
}
