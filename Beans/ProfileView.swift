import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var showLogin = false
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let user = auth.user {
                        accountCard(user)
                        libraryCard
                        logoutButton
                    } else {
                        loginCard
                    }
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.beansBackground.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 6) {
            Text("我的")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Color.beansCream)
            Text("账号与你的网易云音乐")
                .font(.footnote)
                .foregroundStyle(Color.beansMuted)
        }
        .padding(.top, 10)
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.beansAmber.opacity(0.35), Color.beansSage.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.beansCream)
            }
            .padding(.top, 4)
            VStack(spacing: 6) {
                Text("登录网易云账号")
                    .font(.title3.bold())
                    .foregroundStyle(Color.beansCream)
                Text("扫码登录后，自动同步你的收藏、歌单与「我喜欢的音乐」")
                    .font(.footnote)
                    .foregroundStyle(Color.beansMuted)
                    .multilineTextAlignment(.center)
            }
            Button {
                showLogin = true
            } label: {
                Text("立即登录")
                    .font(.headline)
                    .foregroundStyle(Color.beansBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.beansAmber))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func accountCard(_ user: NetEaseUser) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.beansMuted)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text(user.nickname)
                    .font(.title3.bold())
                    .foregroundStyle(Color.beansCream)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(Color.beansSage).frame(width: 7, height: 7)
                    Text("已连接网易云")
                        .font(.caption)
                        .foregroundStyle(Color.beansMuted)
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
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的音乐")
                .font(.headline)
                .foregroundStyle(Color.beansCream)
            HStack(spacing: 12) {
                statCell(icon: "heart.fill", tint: .pink, value: "\(auth.favoriteTracks.count)", label: "喜欢的音乐")
                statCell(icon: "music.note.list", tint: Color.beansAmber, value: "\(auth.playlists.count)", label: "歌单")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func statCell(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(Color.beansCream)
                Text(label).font(.caption2).foregroundStyle(Color.beansMuted)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var logoutButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            HStack {
                Spacer()
                Label("退出登录", systemImage: "arrow.right.square")
                    .font(.subheadline)
                    .foregroundStyle(Color.beansMuted)
                Spacer()
            }
            .padding(.vertical, 13)
            .background(.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关于")
                .font(.headline)
                .foregroundStyle(Color.beansCream)
            HStack {
                Text("Beans").foregroundStyle(Color.beansCream)
                Spacer()
                Text("1.0").foregroundStyle(Color.beansMuted)
            }
            .font(.subheadline)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.beansMuted)
                Text("音乐数据与登录均由网易云音乐提供，Beans 仅作第三方播放器使用。")
                    .font(.caption)
                    .foregroundStyle(Color.beansMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}