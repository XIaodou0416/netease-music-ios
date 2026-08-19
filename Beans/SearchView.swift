import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @State private var keyword = ""
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var searched = false
    @State private var hotKeywords: [String] = []
    @State private var history: [String] = UserDefaults.standard.stringArray(forKey: "beans.searchhistory") ?? []

    var body: some View {
        Group {
            if !searched {
                initialContent
            } else {
                resultsList
            }
        }
        .background(Color.beansBackground.ignoresSafeArea())
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $keyword, prompt: "歌名 / 歌手 / 专辑")
        .onSubmit(of: .search) { runSearch() }
        .task {
            if hotKeywords.isEmpty {
                hotKeywords = (try? await NetEaseAPI.shared.hotSearch()) ?? []
            }
        }
    }

    // MARK: - 初始页：历史 + 热门

    private var initialContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史").font(.headline).foregroundStyle(Color.beansLabel)
                            Spacer()
                            Button {
                                history = []
                                UserDefaults.standard.set([String](), forKey: "beans.searchhistory")
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(Color.beansSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        FlowLayout(spacing: 10) {
                            ForEach(history, id: \.self) { item in
                                Button {
                                    keyword = item
                                    runSearch()
                                } label: {
                                    Text(item)
                                        .font(.footnote)
                                        .foregroundStyle(Color.beansLabel)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.beansCard, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !hotKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("热门搜索").font(.headline).foregroundStyle(Color.beansLabel)
                        FlowLayout(spacing: 10) {
                            ForEach(Array(hotKeywords.enumerated()), id: \.element) { index, item in
                                Button {
                                    keyword = item
                                    runSearch()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("\(index + 1)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansSecondary)
                                        Text(item)
                                            .font(.footnote)
                                            .foregroundStyle(Color.beansLabel)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.beansCard, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - 结果

    private var resultsList: some View {
        Group {
            if songs.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.beansSecondary)
                    Text("没有找到相关歌曲")
                        .font(.headline)
                        .foregroundStyle(Color.beansLabel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongCell(song: song) {
                            player.play(songs: songs, startAt: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveHistory(trimmed)
        searched = true
        isLoading = true
        Task {
            defer { isLoading = false }
            songs = (try? await NetEaseAPI.shared.search(keyword: trimmed)) ?? []
        }
    }

    private func saveHistory(_ item: String) {
        history.removeAll { $0 == item }
        history.insert(item, at: 0)
        if history.count > 12 {
            history = Array(history.prefix(12))
        }
        UserDefaults.standard.set(history, forKey: "beans.searchhistory")
    }
}

// 简单流式布局（chips 自动换行）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}