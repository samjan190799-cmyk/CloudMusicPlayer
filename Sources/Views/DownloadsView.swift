import SwiftUI

/// Вкладка для отображения скачанной музыки и активных загрузок в реальном времени
struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    
    var filteredTracks: [LocalTrack] {
        if searchText.isEmpty {
            return downloadManager.localTracks
        } else {
            return downloadManager.localTracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фоновый градиент темы
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Активные загрузки в процессе
                    let activeList = downloadManager.activeDownloadsList
                    if !activeList.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Загружается сейчас (\(activeList.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 8) {
                                    ForEach(activeList) { download in
                                        HStack(spacing: 12) {
                                            // Иконка источника
                                            Image(systemName: download.source == .youtube ? "play.rectangle.fill" : (download.source == .google ? "cloud.fill" : "icloud.fill"))
                                                .foregroundColor(download.source == .youtube ? .red : (download.source == .google ? .purple : .cyan))
                                                .frame(width: 24, height: 24)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(download.title)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 8) {
                                                    ProgressView(value: download.progress)
                                                        .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                                                    
                                                    Text("\(Int(download.progress * 100))%")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            // Отмена загрузки
                                            Button(action: {
                                                downloadManager.cancelDownload(trackId: download.id)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 18))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(maxHeight: 180)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.top, 4)
                        }
                    }
                    
                    // Поиск
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Поиск среди скачанных...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    
                    if filteredTracks.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text(searchText.isEmpty ? "Нет скачанных файлов" : "Ничего не найдено")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(searchText.isEmpty ? "Скачивайте песни с YouTube или из облачных дисков во вкладках ниже для прослушивания офлайн." : "Попробуйте изменить поисковый запрос.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredTracks) { localTrack in
                                let isPlayingThis = playerManager.currentTrack?.id == localTrack.id
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        playLocalTrack(localTrack)
                                    }) {
                                        HStack(spacing: 12) {
                                            // Обложка / Иконка
                                            ZStack {
                                                if let coverURL = localTrack.localCoverURL,
                                                   let uiImage = UIImage(contentsOfFile: coverURL.path) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.white.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                    
                                                    Image(systemName: isPlayingThis ? "speaker.wave.3.fill" : "music.note")
                                                        .foregroundColor(isPlayingThis ? .cyan : .white)
                                                }
                                            }
                                            
                                            // Название и метаданные
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(localTrack.title)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(isPlayingThis ? .cyan : .white)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 8) {
                                                    Text(localTrack.artist ?? localTrack.source.displayName)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.purple.opacity(0.8))
                                                        .lineLimit(1)
                                                    
                                                    Text(formatSize(localTrack.size))
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Меню удаления
                                    Menu {
                                        Button(role: .destructive, action: {
                                            deleteTrack(localTrack)
                                        }) {
                                            Label("Удалить из загрузок", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 12)
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Color.white.opacity(0.04))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTrack(localTrack)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                    }
                }
            }
            .navigationTitle("Загрузки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredTracks.isEmpty {
                        Button(action: {
                            if let first = filteredTracks.first {
                                playLocalTrack(first)
                            }
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func playLocalTrack(_ track: LocalTrack) {
        let playerTrack = track.toPlayerTrack()
        let queue = downloadManager.localTracks.map { $0.toPlayerTrack() }
        playerManager.play(track: playerTrack, in: queue)
    }
    
    private func deleteTrack(_ track: LocalTrack) {
        downloadManager.deleteTrack(trackId: track.id)
        if playerManager.currentTrack?.id == track.id {
            playerManager.previousTrack()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
