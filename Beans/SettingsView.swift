import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    Section {
                        HStack(spacing: 12) {
                            AsyncImage(url: user.avatarURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.beansMuted)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.nickname).font(.headline).foregroundStyle(Color.beansCream)
                                Text("网易云账号已连接")
                                    .font(.caption)
                                    .foregroundStyle(Color.beansMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Section {
                        Button(role: .destructive) {
                            auth.logout()
                        } label: {
                            Label("退出登录", systemImage: "arrow.right.square")
                        }
                    }
                } else {
                    Text("未登录")
                        .foregroundStyle(Color.beansMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.beansBackground.ignoresSafeArea())
            .navigationTitle("设置")
        }
    }
}