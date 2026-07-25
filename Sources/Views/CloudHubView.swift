import SwiftUI

/// Единый хаб для облачных хранилищ (Google Drive + Яндекс Диск + Telegram)
struct CloudHubView: View {
    @State private var selectedSource: CloudSource = .google
    @Binding var selectedTab: Int

    var body: some View {
        ZStack(alignment: .top) {
            // Динамический эмбиент-фон в стиле Liquid Glass 2026
            AmbientBackgroundView(
                accentColor: selectedSource == .google ? Color.blue : (selectedSource == .yandex ? Color.red : Color.cyan),
                secondaryColor: AppTheme.neonPurple
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Хедер хаба
                headerSection

                // Сегментированный стеклянный переключатель хранилищ
                cloudSourcePicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Содержимое выбранного облака
                CloudView(source: selectedSource, selectedTab: $selectedTab)
                    .id(selectedSource) // Пересоздаем вид для активации fetchAudioFiles
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Хедер

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Облачные сервисы")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Стриминг и загрузка вашей музыки из облака")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.neonPurple.opacity(0.4), AppTheme.neonCyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 4)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, AppTheme.neonPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Сегментированный переключатель облаков (Liquid Glass)

    private var cloudSourcePicker: some View {
        HStack(spacing: 4) {
            CloudTabButton(
                label: "Google Диск",
                icon: "g.circle.fill",
                isSelected: selectedSource == .google,
                activeColor: .blue
            ) {
                switchSource(.google)
            }

            CloudTabButton(
                label: "Яндекс Диск",
                icon: "y.circle.fill",
                isSelected: selectedSource == .yandex,
                activeColor: .red
            ) {
                switchSource(.yandex)
            }

            CloudTabButton(
                label: "Telegram",
                icon: "paperplane.fill",
                isSelected: selectedSource == .telegram,
                activeColor: .cyan
            ) {
                switchSource(.telegram)
            }
        }
        .padding(4)
        .liquidGlass(cornerRadius: 18, opacity: 0.5)
    }

    private func switchSource(_ source: CloudSource) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedSource = source
            HapticManager.shared.triggerSelection()
        }
    }
}

// MARK: - Вспомогательная кнопка переключателя

private struct CloudTabButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : AppTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [activeColor.opacity(0.85), activeColor.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .neonGlow(color: activeColor, radius: 8, opacity: 0.4)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(SpringScaleButtonStyle())
    }
}
