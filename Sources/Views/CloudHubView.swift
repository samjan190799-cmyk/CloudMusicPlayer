import SwiftUI

/// Единый хаб для облачных хранилищ (Google Drive + Яндекс Диск)
struct CloudHubView: View {
    @State private var selectedSource: CloudSource = .google
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .top) {
            // Фон
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.09, green: 0.06, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Заголовок + пикер
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Облако")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Ваши аудиофайлы из облачных хранилищ")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Сегментированный переключатель облаков
                    HStack(spacing: 0) {
                        CloudTabButton(
                            label: "Google Диск",
                            icon: "g.circle.fill",
                            isSelected: selectedSource == .google,
                            color: .blue
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedSource = .google
                                HapticManager.shared.triggerSelection()
                            }
                        }

                        CloudTabButton(
                            label: "Яндекс Диск",
                            icon: "y.circle.fill",
                            isSelected: selectedSource == .yandex,
                            color: .red
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedSource = .yandex
                                HapticManager.shared.triggerSelection()
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(
                    Color(red: 0.05, green: 0.08, blue: 0.16)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )

                // Содержимое активного облака
                CloudView(source: selectedSource, selectedTab: $selectedTab)
                    .navigationBarHidden(true)
                    .id(selectedSource) // Пересоздать при смене — тригерит onAppear
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Вспомогательная кнопка переключателя

private struct CloudTabButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [color.opacity(0.75), color.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
                    } else {
                        Color.clear
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Локальный ScaleButtonStyle (без конфликтов)

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
