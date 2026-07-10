import SwiftUI

/// Модальный экран добавления трека в плейлист
struct AddToPlaylistView: View {
    let track: PlaylistTrack
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    @State private var showingCreateAlert = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Задний фон с красивым размытым градиентом
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.05, blue: 0.16), Color(red: 0.04, green: 0.04, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Информация о добавляемом треке
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Добавление в плейлист:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                    .opacity(0.8)
                                
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    if playlistManager.playlists.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("Нет плейлистов")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Создайте свой первый плейлист, чтобы группировать любимую музыку.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showingCreateAlert = true
                            }) {
                                Text("Создать плейлист")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(12)
                            }
                        }
                        Spacer()
                    } else {
                        // Список плейлистов
                        List {
                            ForEach(playlistManager.playlists) { playlist in
                                Button(action: {
                                    playlistManager.addTrack(track, to: playlist.id)
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(playlist.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("\(playlist.tracks.count) треков")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.cyan)
                                            .font(.title3)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white.opacity(0.04))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Добавить в...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !playlistManager.playlists.isEmpty {
                        Button(action: {
                            showingCreateAlert = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateAlert) {
                CreatePlaylistDialog(isPresented: $showingCreateAlert, playlistName: $newPlaylistName) {
                    playlistManager.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Красивое модальное окно для создания плейлиста
struct CreatePlaylistDialog: View {
    @Binding var isPresented: Bool
    @Binding var playlistName: String
    var onCreate: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.08, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Новый плейлист")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    
                TextField("Введите название...", text: $playlistName)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                
                HStack(spacing: 16) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Отмена")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        onCreate()
                        isPresented = false
                    }) {
                        Text("Создать")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(10)
                    }
                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 32)
            .background(Color.white.opacity(0.03))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
