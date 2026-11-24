# Cloud Music Player (iOS) — Нативный музыкальный плеер

[![Build CloudMusicPlayer iOS IPA](https://github.com/samjan190799-cmyk/CloudMusicPlayer/actions/workflows/swift-ci.yml/badge.svg)](https://github.com/samjan190799-cmyk/CloudMusicPlayer/actions/workflows/swift-ci.yml)

Нативное приложение для iOS 16+ на **Swift** и **SwiftUI**. Слушайте свою музыку онлайн и офлайн из Google Диска, Яндекс Диска, Telegram, YouTube, приложения «Файлы» и медиатеки iPhone — в одном плеере и без подписок.

---

## 🎨 Дизайн «Aurora»

- **Тёмная многослойная тема** с одним акцентным цветом на выбор (Коралл, Фиалка, Мята, Небо, Янтарь, Роза).
- **Плеер в цветах обложки**: мини-плеер и полноэкранный плеер окрашиваются доминирующим цветом текущего трека.
- **Обложка в центре**: большая обложка «дышит» — уменьшается на паузе, свайп влево/вправо переключает трек, двойной тап добавляет в избранное.
- **Сгенерированные обложки**: у треков без картинки — свой стабильный градиент с буквой.
- **Чистые названия**: «Artist - Song (Official Video).mp3» показывается как «Song · Artist».

## ✨ Возможности

- **Главная** — приветствие, «Избранное», «Микс дня» (новый каждый день), «Перемешать всё», «Продолжить слушать», «Часто слушаете», плейлисты и новинки медиатеки.
- **Поиск** — один поиск сразу по медиатеке, плейлистам, облаку и YouTube; чарты по регионам, жанры, подкасты и аудиокниги (с запоминанием места).
- **Медиатека** — вся локальная музыка (скачанное, импорт, «Файлы», музыка iPhone), сортировка, исполнители, плейлисты с мозаичными обложками.
- **Облако** — подключение Google Диска, Яндекс Диска и Telegram-бота, импорт из «Файлов», загрузки с прогрессом.
- **Очередь** — «Играть следующим», «В конец очереди», перетаскивание и удаление треков.
- **Плеер** — перемотка, повтор/перемешивание, скорость 0.75×–2×, таймер сна, AirPlay, системная громкость, экран блокировки, гарнитура и виджет.

---

## 📂 Структура исходного кода

```
Sources/
├── CloudMusicPlayerApp.swift      — точка входа, аудиосессия
├── Services/                      — воспроизведение, загрузки, облака, YouTube, история
│   ├── AudioPlayerManager.swift   — AVPlayer, очередь, Now Playing, Remote Command Center
│   ├── ListeningHistory.swift     — история прослушиваний для главной
│   └── …
├── Views/
│   ├── Design/                    — дизайн-система: Theme, Artwork, Components, TrackText
│   ├── ContentView.swift          — вкладки, мини-плеер, полноэкранный плеер
│   ├── AppRouter.swift            — навигация, общие листы, уведомления
│   ├── Home/ Explore/ Library/ Cloud/ Playlists/ Settings/
│   └── Player/                    — MiniPlayerView, NowPlayingView, QueueView
└── Widget/                        — виджет управления воспроизведением
```

Правила дизайна для разработчиков и ИИ-агентов — в [`.agents/AGENTS.md`](.agents/AGENTS.md).

---

## 🚀 Сборка

Проект генерируется из `project.yml` с помощью [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open CloudMusicPlayer.xcodeproj
```

Выберите свою команду в **Signing & Capabilities** и запустите на устройстве или симуляторе (`Cmd + R`). Фоновое воспроизведение уже включено в `Info.plist` (`UIBackgroundModes: audio`).

CI (`.github/workflows/swift-ci.yml`) собирает неподписанный IPA на каждый push в `main`; `deploy-testflight.yml` отправляет сборку в TestFlight.
