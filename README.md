# Cloud Music Player (iOS) — Нативный музыкальный плеер

[![Build CloudMusicPlayer iOS IPA](https://github.com/samjan190799-cmyk/CloudMusicPlayer/actions/workflows/swift-ci.yml/badge.svg)](https://github.com/samjan190799-cmyk/CloudMusicPlayer/actions/workflows/swift-ci.yml)

Нативное мобильное приложение для iOS (iOS 16+), разработанное на языке **Swift** с использованием современного декларативного фреймворка **SwiftUI**. Приложение позволяет прослушивать музыку как в режиме онлайн-стриминга, так и офлайн (скачивая треки в память устройства) из ваших аккаунтов Google Диска и Яндекс Диска.

---

## 🎨 Дизайн и интерфейс (Glassmorphism 2.0)

Интерфейс приложения выполнен в премиальном стиле **Glassmorphism**:
- Полупрозрачные панели (эффект матового стекла) с размытием фона (`.ultraThinMaterial`).
- Плавные пружинные анимации переходов (`.spring`).
- Вращающаяся обложка-винил при воспроизведении музыки.
- Интегрированный неоновый эквалайзер/аудиовизуализатор, реагирующий на проигрывание.
- Интеграция с экраном блокировки iOS (Now Playing Info) и поддержка кнопок управления на наушниках/системной шторке (Remote Command Center).

---

## 📂 Структура исходного кода проекта

Все исходные файлы приложения структурированы по стандартам iOS-разработки и находятся по пути:
`C:\Users\Samvel\.gemini\antigravity-ide\scratch\CloudMusicPlayer\`

### Сервисы и менеджеры (Services):
- **[AudioPlayerManager.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Services/AudioPlayerManager.swift)** — Синглтон для управления воспроизведением аудио через `AVPlayer`. Отвечает за фоновое проигрывание, системный пульт управления (`MPRemoteCommandCenter`) и вывод метаданных на экран блокировки.
- **[DownloadManager.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Services/DownloadManager.swift)** — Менеджер загрузок. Скачивает аудиофайлы в директорию `Documents` в фоне и обновляет базу данных локальной медиатеки `Library.json`.
- **[GoogleDriveService.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Services/GoogleDriveService.swift)** — Сервис работы с Google Drive REST API v3 (авторизация, получение списка аудиофайлов, авторизованное скачивание по OAuth-токену).
- **[YandexDiskService.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Services/YandexDiskService.swift)** — Сервис работы с API Яндекс.Диска (запрос файлов с фильтром по аудио, получение временных ссылок на скачивание/стриминг).

### Интерфейс SwiftUI (Views):
- **[CloudMusicPlayerApp.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/CloudMusicPlayerApp.swift)** — Точка входа в приложение. Настраивает аудиосессию (`AVAudioSession`) для воспроизведения музыки в фоне при запуске.
- **[ContentView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/ContentView.swift)** — Корневой контейнер вкладок с поддержкой нижнего плавающего мини-плеера.
- **[LibraryView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/LibraryView.swift)** — Вкладка локальной медиатеки (офлайн-файлы, поиск по названию, удаление через Swipe).
- **[CloudView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/CloudView.swift)** — Универсальная вкладка для просмотра треков на дисках Google и Яндекс. Отображает статус загрузки и позволяет слушать файлы онлайн.
- **[SettingsView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/SettingsView.swift)** — Экран настроек, где пользователь вводит API-ключи и авторизуется в дисках.
- **[MiniPlayerView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/Components/MiniPlayerView.swift)** — Плавающий мини-плеер внизу экрана с кнопками быстрого управления.
- **[PlayerDetailView.swift](file:///C:/Users/Samvel/.gemini/antigravity-ide/scratch/CloudMusicPlayer/Sources/Views/Components/PlayerDetailView.swift)** — Полноэкранный плеер с вращающимся диском, таймлайном, регулятором громкости и прыгающим визуализатором.

---

## 🚀 Пошаговая инструкция по запуску проекта на Mac (через Xcode)

Поскольку файлы кода созданы на Windows, вам нужно перенести их на Mac и открыть в Xcode. Выполните следующие шаги:

1. **Создайте проект в Xcode**:
   - Откройте Xcode на Mac и выберите **File** -> **New** -> **Project**.
   - Выберите шаблон **App** (раздел iOS) и нажмите *Next*.
   - Укажите имя проекта: `CloudMusicPlayer`.
   - В поле **Interface** выберите **SwiftUI**, а в **Language** — **Swift**.
   - Сохраните проект в любую удобную папку.

2. **Перенесите файлы исходного кода**:
   - Перенесите с Windows-машины папку `Sources` из директории проекта.
   - Перетащите папку `Sources` прямо в панель навигации вашего проекта в Xcode (в левой колонке).
   - При импорте убедитесь, что стоят галочки:
     - `Copy items if needed` (Копировать элементы при необходимости).
     - `Create groups` (Создать группы).
     - Выбран таргет `CloudMusicPlayer` в секции `Add to targets`.
   - Удалите созданный Xcode по умолчанию файл `ContentView.swift`, так как он будет заменен импортированным.

3. **Включите фоновое воспроизведение (Background Audio)**:
   - В левой колонке Xcode выберите имя вашего проекта (самый верхний элемент `CloudMusicPlayer`).
   - Перейдите на вкладку **Signing & Capabilities**.
   - Нажмите кнопку **+ Capability** в левом верхнем углу этой вкладки.
   - Найдите в списке и добавьте **Background Modes**.
   - В появившемся разделе поставьте галочку напротив **Audio, AirPlay, and Picture in Picture**. Это необходимо для того, чтобы плеер продолжал играть музыку, когда вы сворачиваете приложение или блокируете экран.

4. **Запустите приложение**:
   - Выберите желаемый симулятор (например, *iPhone 15*) или подключите физическое устройство.
   - Нажмите кнопку **Play** (или сочетание клавиш `Cmd + R`) для сборки и запуска приложения.
