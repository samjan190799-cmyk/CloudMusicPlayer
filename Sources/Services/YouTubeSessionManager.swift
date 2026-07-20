import Foundation

@MainActor
class YouTubeSessionManager: ObservableObject {
    static let shared = YouTubeSessionManager()
    
    private let visitorDataKey = "com.samvel.cloudmusicplayer.visitorData"
    
    @Published var visitorData: String? {
        didSet {
            UserDefaults.standard.set(visitorData, forKey: visitorDataKey)
        }
    }
    
    private init() {
        self.visitorData = UserDefaults.standard.string(forKey: visitorDataKey)
        // Запускаем первоначальное обновление асинхронно при старте
        Task {
            if visitorData == nil {
                _ = await refreshSession()
            }
            setupPeriodicRefresh()
        }
    }
    
    func refreshSession() async -> Bool {
        let url = URL(string: "https://www.youtube.com")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en", forHTTPHeaderField: "accept-language")
        
        // Помечаем запрос, чтобы URLProtocol его не перехватывал рекурсивно
        let nsRequest = request as NSURLRequest
        let mutableRequest = nsRequest.mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "YouTubeURLProtocolHandled", in: mutableRequest)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: mutableRequest as URLRequest)
            if let html = String(data: data, encoding: .utf8),
               let parsedData = parseVisitorData(from: html) {
                self.visitorData = parsedData
                print("YouTubeSessionManager: Успешно обновлен visitorData: \(parsedData)")
                return true
            }
        } catch {
            print("YouTubeSessionManager: Ошибка при обновлении сессии: \(error.localizedDescription)")
        }
        return false
    }
    
    func updateVisitorData(_ newValue: String) {
        if self.visitorData != newValue {
            self.visitorData = newValue
            print("YouTubeSessionManager: Перехвачен и обновлен новый visitorData: \(newValue)")
        }
    }
    
    private func parseVisitorData(from html: String) -> String? {
        let patterns = [
            #""VISITOR_DATA"\s*:\s*"([^"]+)""#,
            #""visitorData"\s*:\s*"([^"]+)""#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }
    
    private func setupPeriodicRefresh() {
        // Регулярное обновление каждые 30 минут
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                _ = await self?.refreshSession()
            }
        }
    }
}
