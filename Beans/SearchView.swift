import SwiftUI

enum SearchProvider: String, CaseIterable, Identifiable {
    case netease = "网易云"
    case qq = "QQ音乐"

    var id: String { rawValue }

    /// 主题色渐变：网易云红 / QQ 绿
    var tint: LinearGradient {
        switch self {
        case .netease: return LinearGradient(
            colors: [Color(red: 0.93, green: 0.22, blue: 0.16), Color(red: 0.80, green: 0.15, blue: 0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        case .qq: return LinearGradient(
            colors: [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.05, green: 0.58, blue: 0.42)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var icon: String {
        switch self {
        case .netease: return "cloud.fill"
        case .qq: return "play.rectangle.fill"
        }
    }
}

enum SearchResultType: String, CaseIterable, Identifiable {
    case song = "歌曲"
    case artist = "歌手"
    case album = "专辑"

    var id: String { rawValue }
}

struct SearchView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var keyword = ""
    @State private var provider: SearchProvider = .netease
    @State private var resultType: SearchResultType = .song
    @State private var songResults: [Song] = []
    @State private var artistResults: [Artist] = []
    @State private var albumResults: [Album] = []
    @State private var hotWords: [String] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var showAddToPlaylist: Song?
    @State private var selectedArtist: Artist?
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        let _ = theme.accent
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                headerTitle
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                providerPicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: provider) {
            hotWords = []
            await loadHotWords()
        }
        .onChange(of: keyword) { _, newValue in
            debounceTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                songResults = []
                artistResults = []
                albumResults = []
                errorMessage = nil
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await startSearch(trimmed)
            }
        }
        .onChange(of: provider) { _, _ in
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            debounceTask?.cancel()
            Task { await startSearch(trimmed) }
        }
        .sheet(item: $showAddToPlaylist) { song in
            AddToPlaylistSheet(song: song)
                .environmentObject(auth)
        }
        .sheet(item: $selectedArtist) { artist in
            ArtistHomeSheet(artist: artist)
                .environmentObject(player)
        }
    }

    // MARK: - 顶部标题

    private var headerTitle: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("搜索")
                .font(BeansFont.appFont(30, .bold))
                .foregroundStyle(Color.beansLabel)
            Spacer(minLength: 0)
            Label(provider.rawValue, systemImage: provider.icon)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.8)
                }
        }
    }

    // MARK: - 内容区（热搜 / 分类+结果 固定占满剩余高度，切换不引起布局跳动）

    @ViewBuilder
    private var contentArea: some View {
        if keyword.isEmpty {
            hotSection
        } else {
            VStack(spacing: 0) {
                typeTabs
                resultsArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 搜索框（液态玻璃胶囊）

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.beansSecondary)
            TextField("搜索歌曲、歌手、专辑", text: $keyword)
                .font(BeansFont.appFont(15))
                .foregroundStyle(Color.beansLabel)
                .focused($focused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    // 输入法回车：先失焦提交拼音再延迟读取，避免中文输入法未上屏时读到旧值
                    commitSearch()
                }
            if searching {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.beansAmber)
            }
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                    songResults = []
                    artistResults = []
                    albumResults = []
                    errorMessage = nil
                    debounceTask?.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansSecondary.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            Button {
                commitSearch()
            } label: {
                Text("搜索")
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.8)
                    }
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .beansCardShadow(radius: 8, y: 3)
    }

    // MARK: - 平台选择（等宽分段控件）

    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(SearchProvider.allCases) { p in
                Button {
                    BeansHaptics.tap()
                    if provider != p { provider = p }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: p.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(p.rawValue)
                            .font(BeansFont.appFont(13, .semibold))
                    }
                    .foregroundStyle(provider == p ? Color.white : Color.beansSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if provider == p {
                            Capsule().fill(p.tint)
                        } else {
                            Capsule().fill(.clear)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
        }
        .clipShape(Capsule())
    }

    // MARK: - 分类选择（歌曲 / 歌手 / 专辑）

    private var typeTabs: some View {
        HStack(spacing: 4) {
            ForEach(SearchResultType.allCases) { type in
                Button {
                    BeansHaptics.tap()
                    guard resultType != type else { return }
                    resultType = type
                    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let hasResult: Bool = {
                            switch type {
                            case .song: return !songResults.isEmpty
                            case .artist: return !artistResults.isEmpty
                            case .album: return !albumResults.isEmpty
                            }
                        }()
                        if !hasResult {
                            Task { await startSearch(trimmed) }
                        }
                    }
                } label: {
                    Text(type.rawValue)
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(resultType == type ? Color.beansLabel : Color.beansSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if resultType == type {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            GlassEffectContainer {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.clear, in: Capsule())
            }
        }
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
        }
        .clipShape(Capsule())
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: - 热搜（排名卡片）

    private var hotSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionHeader(title: "\(provider.rawValue)热搜")
                    Spacer()
                    Text("点击直接搜索")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansSecondary)
                }
                .padding(.top, 6)

                if hotWords.isEmpty {
                    LoadingStateView()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(hotWords.enumerated()), id: \.offset) { index, word in
                            hotRow(index: index, word: word)
                        }
                    }
                }
                Spacer().frame(height: 130)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func hotRow(index: Int, word: String) -> some View {
        Button {
            BeansHaptics.tap()
            keyword = word
            focused = false
            debounceTask?.cancel()
            Task { await startSearch(word) }
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(BeansFont.appFont(16, .bold, .rounded))
                    .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansSecondary)
                    .frame(width: 26, alignment: .leading)
                Text(word)
                    .font(BeansFont.appFont(15, .medium))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansSecondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                GlassEffectContainer {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultsArea: some View {
        switch resultType {
        case .song: songResultsArea
        case .artist: artistResultsArea
        case .album: albumResultsArea
        }
    }

    private var songResultsArea: some View {
        Group {
            if let errorMessage, songResults.isEmpty {
                ErrorStateView(message: errorMessage) { submitSearch() }
            } else if searching && songResults.isEmpty {
                LoadingStateView()
            } else if songResults.isEmpty {
                EmptyStateView(icon: "music.note", text: "\(provider.rawValue)未找到相关歌曲")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("找到 \(songResults.count) 首 · \(provider.rawValue)")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                            Button {
                                BeansHaptics.tap()
                                player.play(songs: songResults, startAt: 0)
                            } label: {
                                Label("播放全部", systemImage: "play.fill")
                                    .font(BeansFont.appFont(12, .semibold))
                                    .foregroundStyle(Color.beansAmber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        ForEach(Array(songResults.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song) {
                                BeansHaptics.tap()
                                player.play(songs: songResults, startAt: index)
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 3)
                            .background {
                                GlassEffectContainer {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.clear)
                                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                        lineWidth: 0.8
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 180)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .top) {
                    if searching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.beansAmber)
                            .padding(.top, 10)
                    }
                }
            }
        }
    }

    private var artistResultsArea: some View {
        Group {
            if let errorMessage, artistResults.isEmpty {
                ErrorStateView(message: errorMessage) { submitSearch() }
            } else if searching && artistResults.isEmpty {
                LoadingStateView()
            } else if artistResults.isEmpty {
                EmptyStateView(icon: "person.crop.circle", text: "\(provider.rawValue)未找到相关歌手")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("找到 \(artistResults.count) 位 · \(provider.rawValue)")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        ForEach(artistResults) { artist in
                            Button {
                                BeansHaptics.tap()
                                selectedArtist = artist
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: artist.coverURL, size: 46, cornerRadius: 23)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(artist.name)
                                            .font(BeansFont.appFont(15, .medium))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text("查看歌手主页")
                                            .font(BeansFont.appFont(12))
                                            .foregroundStyle(Color.beansSecondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.beansSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .background {
                                    GlassEffectContainer {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.clear)
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                            lineWidth: 0.8
                                        )
                                }
                            }
                            .buttonStyle(GlassPressButtonStyle(scale: 0.97))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 180)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .top) {
                    if searching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.beansAmber)
                            .padding(.top, 10)
                    }
                }
            }
        }
    }

    private var albumResultsArea: some View {
        Group {
            if let errorMessage, albumResults.isEmpty {
                ErrorStateView(message: errorMessage) { submitSearch() }
            } else if searching && albumResults.isEmpty {
                LoadingStateView()
            } else if albumResults.isEmpty {
                EmptyStateView(icon: "square.stack", text: "\(provider.rawValue)未找到相关专辑")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("找到 \(albumResults.count) 张 · \(provider.rawValue)")
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        ForEach(albumResults) { album in
                            Button {
                                searchBy(album.name)
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: album.coverURL, size: 46, cornerRadius: 10)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(album.name)
                                            .font(BeansFont.appFont(15, .medium))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text(album.artistName.isEmpty ? "未知歌手" : album.artistName)
                                            .font(BeansFont.appFont(12))
                                            .foregroundStyle(Color.beansSecondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.beansSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .background {
                                    GlassEffectContainer {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.clear)
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                                            lineWidth: 0.8
                                        )
                                }
                            }
                            .buttonStyle(GlassPressButtonStyle(scale: 0.97))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 180)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .top) {
                    if searching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.beansAmber)
                            .padding(.top, 10)
                    }
                }
            }
        }
    }

    // MARK: - 动作

    private func submitSearch() {
        // 键盘搜索键：系统已把输入法文本提交到 binding，直接搜索
        debounceTask?.cancel()
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await startSearch(trimmed) }
    }

    /// 点搜索按钮 / 输入法回车：
    /// 优先直接搜索已上屏文本；若输入法还在组字（拼音未上屏），
    /// 等待短时间让拼音自动提交后再读取。
    /// 重点：绝不在组字中失焦（失焦会取消组字，导致输入框被清空、搜索无结果）。
    private func commitSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        debounceTask?.cancel()
        if !trimmed.isEmpty {
            Task { await startSearch(trimmed) }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let t = self.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            self.debounceTask?.cancel()
            Task { await self.startSearch(t) }
        }
    }

    /// 点击歌手 / 专辑：以其名称搜索歌曲
    private func searchBy(_ name: String) {
        BeansHaptics.tap()
        keyword = name
        focused = false
        debounceTask?.cancel()
        resultType = .song
        Task { await startSearch(name) }
    }

    private func loadHotWords() async {
        if provider == .qq {
            if let words = try? await QQMusicAPI.shared.hotKeys() {
                hotWords = words
            }
        } else if let words = try? await NetEaseAPI.shared.hotSearch() {
            hotWords = words
        }
    }

    private func startSearch(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task {
            searching = true
            errorMessage = nil
            defer { if !Task.isCancelled { searching = false } }
            do {
                switch (provider, resultType) {
                case (.netease, .song):
                    let songs = try await NetEaseAPI.shared.search(keyword: trimmed, limit: 40)
                    guard !Task.isCancelled else { return }
                    songResults = songs
                    if !songs.isEmpty { BeansHaptics.success() }
                case (.netease, .artist):
                    let artists = try await NetEaseAPI.shared.searchArtists(keyword: trimmed)
                    guard !Task.isCancelled else { return }
                    artistResults = artists
                case (.netease, .album):
                    let albums = try await NetEaseAPI.shared.searchAlbums(keyword: trimmed)
                    guard !Task.isCancelled else { return }
                    albumResults = albums
                case (.qq, .song):
                    let songs = try await QQMusicAPI.shared.searchSongs(keyword: trimmed)
                    guard !Task.isCancelled else { return }
                    songResults = songs
                    if !songs.isEmpty { BeansHaptics.success() }
                case (.qq, .artist):
                    let artists = try await QQMusicAPI.shared.searchArtists(keyword: trimmed)
                    guard !Task.isCancelled else { return }
                    artistResults = artists
                case (.qq, .album):
                    let albums = try await QQMusicAPI.shared.searchAlbums(keyword: trimmed)
                    guard !Task.isCancelled else { return }
                    albumResults = albums
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
        await searchTask?.value
    }
}
