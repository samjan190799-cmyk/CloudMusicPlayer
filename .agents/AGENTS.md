# Специфические правила разработки CloudMusicPlayer

Этот документ дополняет глобальные правила системы и содержит контекст, уникальный для проекта CloudMusicPlayer.

## 1. Специфика YouTube и стриминга (Стандарты 2026 года)
* **Клиент YouTubeKit & InnerTube:** Всегда использовать исключительно прямое воспроизведение через нативный `YouTubeKit` (M4A / 128kbps AAC) и поиск через нативный InnerTube API без промежуточных серверов или зеркал. Инициализировать клиентские сессии с сохранением и регулярным обновлением visitor data (`X-Goog-Visitor-Id`).
* **Фоновое воспроизведение (Screen Off):** Использовать буфер `preferredForwardBufferDuration = 30.0` и политику `AVAudioSessionRouteSharingPolicy.longFormAudio`. Отслеживать `AVPlayerItemPlaybackStalled` для защиты от сбоев соединения.
* **Обработка обложек:** Качество обложек YouTube запрашивать по цепочке fallback: `maxresdefault` (проверяя ширину > 120px) -> `hqdefault` -> `mqdefault` -> `sddefault`. Кешировать изображения через `ThumbnailCache` (`Views/Design/Artwork.swift`).

## 2. Дизайн-система «Aurora» (тёмная, обложка в центре)
* **Токены:** цвета, шрифты, отступы и стили кнопок — только из `Views/Design/Theme.swift` (`Palette`, `Font.app*`, `Metrics`, `PressableButtonStyle`, `PrimaryCapsuleButtonStyle`). Не хардкодить новые цвета на экранах.
* **Акцент:** один акцентный цвет, выбирается в настройках (`AccentTheme`, ключ `accentTheme`). В вью брать его через `@Environment(\.accent)`. Корень приложения и корень каждого `.sheet` оборачивать в `.themed()`.
* **Цвет из обложки:** мини-плеер и полноэкранный плеер окрашиваются доминирующим цветом обложки (`NowPlayingArtwork.shared.color`), если включён `dynamicPlayerColor`.
* **Обложки:** всегда через `ArtworkView(artwork:)` / `NowPlayingArtworkView`. Для треков без обложки — стабильный сгенерированный градиент (`GeneratedCover`, `StableHash`; не использовать `String.hashValue`).
* **Названия:** пользователю показывать `track.display.title` / `track.display.artist` (`TrackText`) — они очищены от расширений, «(Official Video)» и т.п.
* **Списки:** строка трека — `TrackRow`, действия — `TrackMenuItems` (в `Menu` и в `.contextMenu`). Для подсветки текущего трека наблюдать `PlaybackStatus.shared`, а не `AudioPlayerManager` (он публикует время каждую секунду).
* **Навигация:** вкладки и общие листы — через `AppRouter.shared` (`select(_:)`, `expandPlayer()`, `addToPlaylist(_:)`, `showToast(_:)`).
* **Без фейков:** не добавлять имитации визуализаторов и «Dolby Atmos»-плашек — только то, что реально работает.

## 3. Тактильный отклик
* Использовать `HapticManager.shared.triggerImpact(style:)` при нажатии кнопок плеера, `triggerSelection()` — при переключении режимов и вкладок.
