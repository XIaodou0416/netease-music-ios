import SwiftUI

enum SearchProvider: String, CaseIterable, Identifiable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"

    var id: String { rawValue }
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
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        let _ = theme.accent
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                providerPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

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

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.beansSecondary)
            TextField("搜索歌曲、歌手、专辑", text: $keyword)
                .font(.system(size: 15))
                .foregroundStyle(Color.beansLabel)
                .focused($focused)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    submitSearch()
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
                        .foregroundStyle(Color.beansSecondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                commitSearch()
            } label: {
                Text("搜索")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .clipShape(Capsule())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
                .background {
            GlassEffectContainer {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .beansCardShadow(radius: 6, y: 2)
        .padding(.bottom, 6)
    }

    // MARK: - 平台选择（网易云 / QQ音乐）

    private var providerPicker: some View {
        HStack(spacing: 8) {
            ForEach(SearchProvider.allCases) { p in
                Button {
                    BeansHaptics.tap()
                    if provider != p { provider = p }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: p == .netease ? "cloud" : "play.rectangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(p.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(provider == p ? Color.white : Color.beansSecondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background {
                        GlassEffectContainer {
                        if provider == p {
                            Capsule().fill(p == .netease ? LinearGradient.beansAccent : LinearGradient(colors: [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.05, green: 0.58, blue: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else {
                            Capsule().fill(.clear).glassEffect(.clear, in: Capsule())
                        }
                        }
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 分类选择（歌曲 / 歌手 / 专辑）

    private var typeTabs: some View {
        HStack(spacing: 6) {
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(resultType == type ? Color.beansLabel : Color.beansSecondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 7)
                        .background {
                            GlassEffectContainer {
                            if resultType == type {
                                Capsule().fill(.clear).glassEffect(.clear, in: Capsule())
                            }
                            }
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - 热搜

    private var hotSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "\(provider.rawValue)热搜")
                if hotWords.isEmpty {
                    LoadingStateView()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(hotWords.enumerated()), id: \.offset) { index, word in
                            Button {
                                BeansHaptics.tap()
                                keyword = word
                                focused = false
                                debounceTask?.cancel()
                                Task { await startSearch(word) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansSecondary)
                                    Text(word)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                                                .background {
                                    GlassEffectContainer {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.clear)
                                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(GlassPressButtonStyle())
                        }
                    }
                }
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
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
                                .font(.system(size: 12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        ForEach(Array(songResults.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song) {
                                BeansHaptics.tap()
                                player.play(songs: songResults, startAt: index)
                            }
                            Divider().overlay(Color.beansSecondary.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 16)
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
                        ForEach(artistResults) { artist in
                            Button {
                                searchBy(artist.name)
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: artist.coverURL, size: 46, cornerRadius: 23)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(artist.name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text("搜索该歌手的歌曲")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.beansSecondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.beansSecondary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.beansSecondary.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 16)
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
                        ForEach(albumResults) { album in
                            Button {
                                searchBy(album.name)
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: album.coverURL, size: 46, cornerRadius: 10)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(album.name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text(album.artistName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.beansSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    if let count = album.trackCount, count > 0 {
                                        Text("\(count) 首")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.beansSecondary)
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.beansSecondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.beansSecondary.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 16)
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

    /// 点搜索按钮：先让输入法失焦提交拼音，再延迟读取文本，
    /// 避免中文输入法未提交拼音时读到旧值导致“搜空/搜索键无反应”。
    private func commitSearch() {
        focused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let trimmed = self.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            self.debounceTask?.cancel()
            Task { await self.startSearch(trimmed) }
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
