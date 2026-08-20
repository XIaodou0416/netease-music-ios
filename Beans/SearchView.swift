import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore

    @State private var keyword = ""
    @State private var results: [Song] = []
    @State private var hotWords: [String] = []
    @State private var searching = false
    @State private var errorMessage: String?
    @State private var showAddToPlaylist: Song?
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if keyword.isEmpty {
                    hotSection
                } else {
                    resultsArea
                }
            }
            TopFade()
        }
        .task {
            if hotWords.isEmpty {
                if let words = try? await NetEaseAPI.shared.hotSearch() {
                    hotWords = words
                }
            }
        }
        .onChange(of: keyword) { _, newValue in
            debounceTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                results = []
                errorMessage = nil
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await search()
            }
        }
        .sheet(item: $showAddToPlaylist) { song in
            AddToPlaylistSheet(song: song)
                .environmentObject(auth)
        }
    }

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
                    focused = false
                    debounceTask?.cancel()
                    Task { await search() }
                }
            if searching {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.beansAmber)
            }
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                    results = []
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
                focused = false
                debounceTask?.cancel()
                Task { await search() }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.beansAmber)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 6)
    }

    private var hotSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "热门搜索")
                if hotWords.isEmpty {
                    LoadingStateView()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(hotWords.enumerated()), id: \.element) { index, word in
                            Button {
                                BeansHaptics.tap()
                                keyword = word
                                focused = false
                                debounceTask?.cancel()
                                Task { await search() }
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
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .scrollDismissesKeyboard(.immediately)
    }

    private var resultsArea: some View {
        Group {
            if searching && results.isEmpty {
                LoadingStateView()
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await search() }
                }
            } else if results.isEmpty {
                EmptyStateView(icon: "magnifyingglass", text: "未找到「\(keyword)」相关歌曲")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("找到 \(results.count) 首")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.beansSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, song in
                            SongCell(song: song) {
                                BeansHaptics.tap()
                                player.play(songs: results, startAt: index)
                            }
                            Divider().overlay(Color.beansSecondary.opacity(0.15))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 180)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }

    private func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searching = true
        errorMessage = nil
        do {
            results = try await NetEaseAPI.shared.search(keyword: trimmed, limit: 40)
            searching = false
            BeansHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            searching = false
        }
    }
}