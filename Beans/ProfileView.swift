import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue

    @State private var showHistory = false
    @State private var confirmLogout = false
    @State private var showQQLogin = false
    @State private var showLogin = false
    @State private var confirmQQLogout = false
    @State private var bgImageItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var appearanceExpanded = false
    @ObservedObject private var qqAuth = QQMusicAuth.shared

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
                qqCard
                dataSection
                settingsSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }
        .scrollIndicators(.hidden)
        .onChange(of: bgImageItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                    theme.addWallpaper(data)
                    BeansHaptics.success()
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showQQLogin) {
            QQLoginSheet()
                .environmentObject(theme)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                var ok = 0
                for url in urls {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        if !data.isEmpty {
                            theme.addWallpaper(data)
                            ok += 1
                        }
                    } catch {
                        ToastCenter.shared.show("读取文件失败：\(error.localizedDescription)", duration: 2.5)
                    }
                }
                if ok > 0 {
                    BeansHaptics.success()
                    ToastCenter.shared.show("已添加 \(ok) 张壁纸，已应用为当前背景", duration: 2)
                } else {
                    ToastCenter.shared.show("未能读取所选图片，请重试", duration: 2.5)
                }
            case .failure(let error):
                ToastCenter.shared.show("选择失败：\(error.localizedDescription)", duration: 2.5)
            }
        }
        .confirmationDialog("退出登录？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                player.clearHistory()
                auth.logout()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("退出 QQ 音乐？", isPresented: $confirmQQLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                qqAuth.logout()
                ToastCenter.shared.show("已退出 QQ 音乐")
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var userCard: some View {
        Button {
            BeansHaptics.tap()
            // 免登录使用：未登录时点击进入网易云登录（可选，用于同步歌单）
            if !auth.isLoggedIn {
                showLogin = true
            }
        } label: {
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
                    Text(auth.user?.nickname ?? (auth.isLoggedIn ? "未登录" : "免登录 · 点击登录"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text(auth.isLoggedIn ? "UID \(auth.user?.uid ?? 0)" : "登录后可同步网易云歌单")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.beansSecondary)
                }
                Spacer()
                if !auth.isLoggedIn {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansSecondary)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: .rect(cornerRadius: 24))
            }
        }
        .beansCardShadow(radius: 10, y: 4)
    }

    /// QQ 音乐登录状态卡片（扫码登录 / 退出）
    private var qqCard: some View {
        Button {
            BeansHaptics.tap()
            if qqAuth.isLoggedIn {
                confirmQQLogout = true
            } else {
                showQQLogin = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: qqAuth.isLoggedIn ? "checkmark.seal.fill" : "globe")
                    .font(.system(size: 17))
                    .foregroundStyle(qqAuth.isLoggedIn ? Color.beansSage : Color.beansAmber)
                    .frame(width: 38, height: 38)
                    .background(Color.beansGlassFill, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("QQ 音乐")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(qqAuth.isLoggedIn
                         ? "已登录：\(qqAuth.nickname.isEmpty ? "QQ 账号" : qqAuth.nickname)"
                         : "登录后可播放 QQ 音乐歌曲")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: qqAuth.isLoggedIn ? "person.crop.circle.badge.xmark" : "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansSecondary)
            }
            .padding(14)
            .glassEffect(.clear, in: .rect(cornerRadius: 22))
            .beansCardShadow(radius: 9, y: 3)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

    /// 壁纸格子：点击应用为当前背景；使用中的壁纸显示主题色边框+勾选；右上角删除
    private func wallpaperCell(path: String) -> some View {
        let isActive = path == theme.backgroundImagePath
        return ZStack(alignment: .topTrailing) {
            Button {
                BeansHaptics.tap()
                theme.applyWallpaper(at: path)
            } label: {
                Group {
                    if let img = UIImage(contentsOfFile: path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.beansGlassFill
                    }
                }
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.beansAmber : .white.opacity(0.18),
                            lineWidth: isActive ? 2.5 : 1
                        )
                }
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.beansAmber)
                            .background(Circle().fill(.ultraThinMaterial))
                            .padding(5)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                theme.deleteWallpaper(at: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.beansSecondary)
                    .background(Circle().fill(.ultraThinMaterial))
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "外观", trailing: appearanceExpanded ? "收起" : "展开") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    appearanceExpanded.toggle()
                }
            }
            if appearanceExpanded {
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

                Divider().overlay(Color.beansSecondary.opacity(0.15))

                HStack {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("自定义强调色")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { theme.customAccent ?? Color.beansAmber },
                        set: { theme.setCustomAccent($0.hexString) }
                    ))
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        theme.clearCustomAccent()
                        BeansHaptics.select()
                    } label: {
                        Text("恢复预设")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(theme.customAccentHex == nil ? "使用预设主题" : "已自定义")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansSecondary)
                }

                    Divider().overlay(Color.beansSecondary.opacity(0.15))

                    HStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text("主页背景色")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.customBackground ?? Color.beansBackground },
                            set: { theme.setBackground($0.hexString) }
                        ))
                        .labelsHidden()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        PhotosPicker(selection: $bgImageItem, matching: .images) {
                            HStack(spacing: 8) {
                                Text("上传壁纸（可多张）")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("从文件选择壁纸")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    // 壁纸库：所有已上传壁纸，点击即应用为当前背景
                    if !theme.wallpaperPaths.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(theme.wallpaperPaths, id: \.self) { path in
                                wallpaperCell(path: path)
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansSecondary)
                            Text("还没有壁纸，上传后会显示在这里")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                        }
                    }
                    HStack(spacing: 12) {
                        if theme.customBackgroundImage != nil {
                            Button {
                                theme.clearBackgroundImage()
                                BeansHaptics.select()
                            } label: {
                                Text("清除当前背景")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text(theme.customBackgroundImage == nil ? "当前：默认背景" : "当前：已应用壁纸")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansSecondary)
                    }
                Toggle(isOn: Binding(
                    get: { theme.backgroundSyncAll },
                    set: { theme.setBackgroundSyncAll($0) }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansAmber)
                        Text("同步到搜索 / 音乐库 / 我的")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.beansLabel)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                HStack {
                    Button {
                        theme.setBackground("")
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认背景")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
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
                Text("仅供学习交流，纯 AI 实现此应用\n接入网易云音乐、QQ 音乐等公开接口，请勿用于商业用途")
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
