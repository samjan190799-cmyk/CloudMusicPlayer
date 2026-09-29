import Foundation

// MARK: - Определение формата аудиофайла

/// Определяет реальный контейнер аудиофайла по сигнатуре. AVPlayer выбирает демультиплексор
/// по расширению локального файла, поэтому M4A с YouTube, сохранённый как .mp3, не воспроизводится.
enum AudioFileSniffer {
    static func fileExtension(for fileURL: URL, fallback: String = "mp3") -> String {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return fallback }
        defer { try? handle.close() }
        let header = [UInt8](handle.readData(ofLength: 12))
        guard header.count >= 4 else { return fallback }

        if header.count >= 8, header[4] == 0x66, header[5] == 0x74, header[6] == 0x79, header[7] == 0x70 {
            return "m4a" // ....ftyp — MP4/M4A (AAC)
        }
        if header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 { return "mp3" } // ID3
        if header[0] == 0xFF, (header[1] & 0xE0) == 0xE0 {
            // MPEG sync: layer 0 у ADTS-AAC, остальное — MP3
            return (header[1] & 0x06) == 0 ? "aac" : "mp3"
        }
        if header[0] == 0x66, header[1] == 0x4C, header[2] == 0x61, header[3] == 0x43 { return "flac" } // fLaC
        if header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46 { return "wav" } // RIFF
        if header[0] == 0x4F, header[1] == 0x67, header[2] == 0x67, header[3] == 0x53 { return "ogg" } // OggS
        if header[0] == 0x1A, header[1] == 0x45, header[2] == 0xDF, header[3] == 0xA3 { return "webm" } // Matroska/WebM
        return fallback
    }

    /// Успешный ли HTTP-ответ у завершённой загрузки (иначе на диск попадёт HTML/JSON с ошибкой)
    static func isSuccessfulDownload(_ task: URLSessionTask) -> Bool {
        guard let http = task.response as? HTTPURLResponse else { return true }
        return (200...299).contains(http.statusCode)
    }
}
