import Foundation

/// Скачивание файла последовательными Range-запросами.
/// googlevideo отдаёт ссылки резервного клиента только кусками: запрос всего файла
/// получает HTTP 403, а запросы по 1 МБ проходят (проверено смоук-тестом).
enum RangedDownloader {
    static let chunkSize: Int64 = 1_048_576

    /// Скачивает `url` в `destination`. Возвращает `false` при ошибке или отмене задачи.
    static func download(
        from url: URL,
        to destination: URL,
        progress: ((Double) -> Void)? = nil
    ) async -> Bool {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: destination)
        guard fileManager.createFile(atPath: destination.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: destination) else {
            return false
        }
        defer { try? handle.close() }

        var offset: Int64 = 0
        var total: Int64? = nil
        var failedAttempts = 0

        while total.map({ offset < $0 }) ?? true {
            if Task.isCancelled { return false }

            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("bytes=\(offset)-\(offset + chunkSize - 1)", forHTTPHeaderField: "Range")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { return false }

                if http.statusCode == 200 && offset == 0 {
                    // Сервер проигнорировал Range и отдал файл целиком
                    try handle.write(contentsOf: data)
                    progress?(1)
                    return !data.isEmpty
                }

                guard http.statusCode == 206, !data.isEmpty else {
                    print("RangedDownloader: HTTP \(http.statusCode) на смещении \(offset)")
                    failedAttempts += 1
                    if failedAttempts >= 3 { return false }
                    continue
                }

                if total == nil {
                    total = parseTotalLength(http.value(forHTTPHeaderField: "Content-Range"))
                }
                try handle.write(contentsOf: data)
                offset += Int64(data.count)
                failedAttempts = 0

                if let total = total, total > 0 {
                    progress?(min(Double(offset) / Double(total), 1))
                } else if Int64(data.count) < chunkSize {
                    break // размер неизвестен, но пришёл последний кусок
                }
            } catch {
                if Task.isCancelled { return false }
                print("RangedDownloader: ошибка сети на смещении \(offset): \(error.localizedDescription)")
                failedAttempts += 1
                if failedAttempts >= 3 { return false }
            }
        }
        return offset > 0
    }

    /// «bytes 0-1048575/3433041» → 3433041
    static func parseTotalLength(_ header: String?) -> Int64? {
        guard let header = header, let slash = header.lastIndex(of: "/") else { return nil }
        let value = header[header.index(after: slash)...].trimmingCharacters(in: .whitespaces)
        return Int64(value)
    }
}
