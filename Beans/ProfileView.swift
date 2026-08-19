import SwiftUI

struct ProfileView: View {
    @Binding var tab: BeansTab
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.theme") private var themeRaw = BeansThemeMode.system.rawValue
    @State private var showLogin = false
    @State private var showLogoutConfirm = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let user = auth.user {
                        accountCard(user)
                        statsCard
                        if !player.topPlayed.isEmpty {
                            topPlayedCard
                        }
                        servicesCard
                        themeCard
                        aboutCard
                        logoutButton
                    } else {
                        loginCard
                        themeCard
                        aboutCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color.beansBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BeansBottomBar(selected: $tab)
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
                    .presentationDragIndicator(.hidden)
            }
            .confirmationDialog("退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) { auth.logout() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后需要重新扫码登录，云端收藏与歌单不会丢失。")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("我的")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Color.beansLabel)
            Text("账号、主题与你的音乐足迹")
                .font(.footnote)
                .foregroundStyle(Color.beansSecondary)
        }
        .padding(.top, 14)
    }

    // MARK: - 未登录

    private var loginCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.beansAmber.opacity(0.38), Color.beansSage.opacity(0.26)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                        )
                        .glassEffect(.regular)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("登录网易云账号")
                        .font(.title3.bold())
                        .foregroundStyle(Color.beansLabel)
                    Text("扫码登录，同步收藏、歌单与每日推荐")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            Button {
                showLogin = true
            } label: {
                Text("立即登录")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.beansAmber, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - 已登录

    private func accountCard(_ user: NetEaseUser) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.beansSecondary)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text(user.nickname)
                    .font(.title3.bold())
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("已连接网易云")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.beansSage)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.beansSage.opacity(0.14), in: Capsule())
                }
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Color.beansAmber)
        }
        .padding(20)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var statsCard: some View {
        HStack(spacing: 12) {
            statCell(icon: "heart.fill", tint: .pink, value: "\(auth.favoriteTracks.count)", label: "喜欢的音乐")
            statCell(icon: "music.note.list", tint: Color.beansAmber, value: "\(auth.playlists.count)", label: "歌单")
        }
    }

    private func statCell(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(Color.beansLabel)
                Text(label).font(.caption2).foregroundStyle(Color.beansSecondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var topPlayedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("听歌排行").font(.headline).foregroundStyle(Color.beansLabel)
            ForEach(player.topPlayed.prefix(5), id: \.song.id) { item in
                Button {
                    player.play(songs: player.history, startAt: player.history.firstIndex(of: item.song) ?? 0)
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: item.song.coverURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.beansCard)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.song.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(1)
                            Text(item.song.artists)
                                .font(.caption2)
                                .foregroundStyle(Color.beansSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(item.count) 次")
                            .font(.caption2)
                            .foregroundStyle(Color.beansAmber)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var servicesCard: some View {
        VStack(spacing: 0) {
            Button {
                showHistory = true
            } label: {
                serviceRow(icon: "clock.arrow.circlepath", tint: Color.beansSage, title: "最近播放", subtitle: "本地记录 50 首播放足迹")
            }
            Divider().padding(.leading, 52)
            Button {
                showHistory = true
            } label: {
                serviceRow(icon: "chart.bar.fill", tint: .blue, title: "播放统计", subtitle: "听歌次数自动累计")
            }
        }
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func serviceRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.beansLabel)
                Text(subtitle).font(.caption2).foregroundStyle(Color.beansSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.beansSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 设置

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观").font(.headline).foregroundStyle(Color.beansLabel)
            Picker("主题", selection: $themeRaw) {
                ForEach(BeansThemeMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text("选择「跟随系统」会自动切换深浅色")
                .font(.caption2)
                .foregroundStyle(Color.beansSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关于").font(.headline).foregroundStyle(Color.beansLabel)
            HStack {
                Text("Beans").foregroundStyle(Color.beansLabel)
                Spacer()
                Text("1.2").foregroundStyle(Color.beansSecondary)
            }
            .font(.subheadline)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.beansSecondary)
                Text("音乐数据与登录均由网易云音乐提供，Beans 仅作第三方播放器使用。联网播放音乐无需额外授权（iOS 默认允许访问网络）。")
                    .font(.caption)
                    .foregroundStyle(Color.beansSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var logoutButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            HStack {
                Spacer()
                Label("退出登录", systemImage: "arrow.right.square")
                    .font(.subheadline)
                    .foregroundStyle(Color.beansSecondary)
                Spacer()
            }
            .padding(.vertical, 13)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
