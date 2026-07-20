import Foundation

class YouTubeURLProtocol: URLProtocol {
    
    private var activeTask: URLSessionDataTask?
    private static let visitorDataKey = "com.samvel.cloudmusicplayer.visitorData"
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        
        // Перехватываем запросы к доменам YouTube (InnerTube API и веб-запросы)
        let isYouTube = url.host?.contains("youtube") == true
        
        // Не перехватываем прямые ссылки на аудио/видео стримы (они обычно идут на googlevideo.com)
        let isStream = url.host?.contains("googlevideo.com") == true
        
        let isAlreadyHandled = URLProtocol.property(forKey: "YouTubeURLProtocolHandled", in: request) != nil
        
        return isYouTube && !isStream && !isAlreadyHandled
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            self.client?.urlProtocol(self, didFailWithError: NSError(domain: "YouTubeURLProtocol", code: -1, userInfo: nil))
            return
        }
        
        URLProtocol.setProperty(true, forKey: "YouTubeURLProtocolHandled", in: mutableRequest)
        
        // Потокобезопасно получаем visitorData из UserDefaults
        if let visitorData = UserDefaults.standard.string(forKey: Self.visitorDataKey) {
            mutableRequest.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        
        // Подставляем стабильный User-Agent для мобильного Safari
        mutableRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession(configuration: .default)
        activeTask = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
                self.extractVisitorData(from: data, url: mutableRequest.url)
            }
            
            self.client?.urlProtocolDidFinishLoading(self)
        }
        activeTask?.resume()
    }
    
    override func stopLoading() {
        activeTask?.cancel()
        activeTask = nil
    }
    
    private func extractVisitorData(from data: Data, url: URL?) {
        guard let url = url else { return }
        
        if url.path.contains("watch") || url.path.contains("embed") {
            if let html = String(data: data, encoding: .utf8),
               let visitorData = parseVisitorData(from: html) {
                Task { @MainActor in
                    YouTubeSessionManager.shared.updateVisitorData(visitorData)
                }
            }
        } else if url.path.contains("youtubei/v1") {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseContext = json["responseContext"] as? [String: Any],
               let visitorData = responseContext["visitorData"] as? String {
                Task { @MainActor in
                    YouTubeSessionManager.shared.updateVisitorData(visitorData)
                }
            }
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
}
