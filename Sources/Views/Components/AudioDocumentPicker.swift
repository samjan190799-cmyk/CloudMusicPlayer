import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Системный диалог выбора файлов на iOS (UIDocumentPickerViewController).
/// Позволяет пользователю выбирать аудиофайлы прямо из памяти телефона (Files / iCloud / Загрузки).
struct AudioDocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Поддерживаемые типы аудиофайлов (iOS 14+)
        let contentTypes: [UTType] = [
            .audio,
            .mp3,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "ogg") ?? .audio,
            UTType(filenameExtension: "opus") ?? .audio
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioDocumentPicker
        
        init(_ parent: AudioDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Пользователь отменил выбор
        }
    }
}
