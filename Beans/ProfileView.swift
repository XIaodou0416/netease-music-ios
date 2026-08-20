import SwiftUI

// 我的页（全新布局）
struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.theme") private var themeRaw = BeansThemeMode.system.rawValue
    @State private var showLogin = false
    @State private var showLogoutConfirm = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("我的")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.beansLabel)
                        .padding(.top, 8)

                    if let user = auth.user {
                        accountCard(user)
                        statsRow
                        if player.topPlayed.isEmpty {
                            emptyRank
                        } else {
                            rankCard
                        }
                        services
                        themeCard
                        about
                        logoutButton
                    } else {
                        loginCard
                        themeCard
                        about
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
            .beansPage()
            .navigationDestination(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showLogin) {
                LoginView()
                    .presentationDragIndicator(.hidden)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("beans.openLogin"))) { _ in
                showLogin = true
            }
            .confirmationDialog("退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) { auth.logout() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后需要重新扫码登录，云端收藏与歌单不会丢失。")
            }
        }
    }

    // MARK: - 未登录

    private var loginCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.beansAmber.opacity(0.38), Color.beansSage.opacity(0.26)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("登录网易云账号").font(.title3.bold()).foregroundStyle(Color.beansLabel)
                    Text("扫码登录，同步收藏、歌单与每日推荐").font(.footnote).foregroundStyle(Color.beansSecondary)
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
        .beansGlass(padding: 18)
    }

    // MARK: - 已登录

    private func accountCard(_ user: NetEaseUser) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(Color.beansSecondary)
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text(user.nickname).font(.title3.bold()).foregroundStyle(Color.beansLabel).lineLimit(1)
                Text("已连接网易云")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.beansSage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.beansSage.opacity(0.14), in: Capsule())
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Color.beansAmber)
        }
        .beansGlass(padding: 18)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(icon: "heart.fill", tint: .pink, value: "\(auth.favoriteTracks.count)", label: "喜欢的音乐")
            statCell(icon: "music.note.list", tint: Color.beansAmber, value: "\(auth.playlists.count)", label: "歌单")
        }
    }

    private func statCell(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(Color.beansLabel)
                Text(label).font(.caption2).foregroundStyle(Color.beansSecondary)
            }
            Spacer(minLength: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .beansRow(radius: 16)
    }

    private var emptyRank: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.bar").font(.title2).foregroundStyle(Color.beansSecondary)
                .frame(width: 40, height: 40)
                .background(Color.beansSecondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("暂无听歌数据").font(.subheadline.weight(.semibold)).foregroundStyle(Color.beansLabel)
                Text("播放过的歌曲会自动计入听歌排行").font(.caption2).foregroundStyle(Color.beansSecondary)
            }
            Spacer(minLength: 8)
        }
        .beansGlass(padding: 16)
    }

    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("听歌排行").font(.headline).foregroundStyle(Color.beansLabel)
            ForEach(player.topPlayed.prefix(5), id: \.song.id) { item in
                Button {
                    player.play(songs: player.history, startAt: player.history.firstIndex(of: item.song) ?? 0)
                } label: {
                    HStack(spacing: 12) {
                        BeansCover(url: item.song.coverURL, radius: 8).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.song.name).font(.subheadline).foregroundStyle(Color.beansLabel).lineLimit(1)
                            Text(item.song.artists).font(.caption2).foregroundStyle(Color.beansSecondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text("\(item.count) 次").font(.caption.monospacedDigit()).foregroundStyle(Color.beansSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .beansRow(radius: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.beansCard.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 服务 / 设置

    private var services: some View {
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
        .beansGlass(radius: 18, padding: 0)
    }

    private func serviceRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.beansLabel)
                Text(subtitle).font(.caption2).foregroundStyle(Color.beansSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Color.beansSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观").font(.headline).foregroundStyle(Color.beansLabel)
            Picker("主题", selection: $themeRaw) {
                ForEach(BeansThemeMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            Text("选择「跟随系统」会自动切换深浅色").font(.caption2).foregroundStyle(Color.beansSecondary)
        }
        .beansGlass(padding: 14)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关于").font(.headline).foregroundStyle(Color.beansLabel)
            HStack {
                Text("Beans").foregroundStyle(Color.beansLabel)
                Spacer()
                Text("1.2").foregroundStyle(Color.beansSecondary)
            }
            .font(.subheadline)
            Text("音乐数据与登录均由网易云音乐提供，Beans 仅作第三方播放器使用。")
                .font(.caption)
                .foregroundStyle(Color.beansSecondary)
        }
        .beansGlass(padding: 14)
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
            .beansRow(radius: 14)
        }
        .buttonStyle(.plain)
    }
}