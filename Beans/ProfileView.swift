import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    @State private var showHistory = false
    @State private var confirmLogout = false

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var appVersionText: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Beans · \\(ver) (\\(build))"
    }

    var body: some View {
        let _ = theme.accent
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                userCard
                statsRow
                dataSection
                settingsSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(player)
                .environmentObject(auth)
        }
        .confirmationDialog("退出登录？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                player.clearHistory()
                auth.logout()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var userCard: some View {
        HStack(spacing: 14) {
            AsyncImage(url: auth.user?.avatarURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.beansSecondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .background(Color.beansGlassFill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.user?.nickname ?? "未登录")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.beansLabel)
                Text("UID \(auth.user?.uid ?? 0)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.beansSecondary)
            }
            Spacer()
        }
        .padding(16)
        .glassEffect(.clear, in: .rect(cornerRadius: 24))
        .beansCardShadow(radius: 10, y: 4)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(title: "收藏", value: "\(auth.displayedFavoriteCount)", icon: "heart.fill")
            statCard(title: "歌单", value: "\(auth.playlists.count)", icon: "music.note.list")
            statCard(title: "历史", value: "\(player.history.count)", icon: "clock.fill")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.beansAmber)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.beansLabel)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.beansSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.clear, in: .rect(cornerRadius: 20))
        .beansCardShadow(radius: 7, y: 2)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "外观")
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("主题模式")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                }
                Picker("主题模式", selection: $themeModeRaw) {
                    ForEach(BeansThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Divider().overlay(Color.beansSecondary.opacity(0.15))

                HStack {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("播放器配色")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                }
                HStack(spacing: 16) {
                    ForEach(BeansAccent.allCases) { accent in
                        Button {
                            theme.set(accent)
                            BeansHaptics.select()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: accent.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                    }
                                if accent == theme.accent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                    }
                    Spacer()
                }

            }
            .padding(16)
            .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
            .beansCardShadow(radius: 9, y: 3)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "数据")
            VStack(spacing: 0) {
                row(icon: "clock.arrow.circlepath", title: "最近播放", value: "\(player.history.count) 首") {
                    showHistory = true
                }
                Divider().overlay(Color.beansSecondary.opacity(0.15))
                row(icon: "chart.bar.fill", title: "听歌排行", value: "前 \(player.topPlayed.count) 名") {
                    // 顶部排行入口已放在音乐库
                }
                Divider().overlay(Color.beansSecondary.opacity(0.15))
                row(icon: "trash", title: "清除播放历史", value: "") {
                    player.clearHistory()
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
            .beansCardShadow(radius: 8, y: 3)
        }
    }

    private func row(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary.opacity(0.6))
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "关于")
            VStack(spacing: 8) {
                Label(appVersionText, systemImage: "beats.headphones")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                Text("接入网易云音乐非官方接口，仅供个人自用\n部分 VIP / 版权受限歌曲可能无法播放")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassEffect(.clear, in: .rect(cornerRadius: 22))
            .beansCardShadow(radius: 9, y: 3)

            Button(role: .destructive) {
                confirmLogout = true
            } label: {
                Text("退出登录")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
            }
            .buttonStyle(.plain)
        }
    }
}
