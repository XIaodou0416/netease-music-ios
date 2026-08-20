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
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if keyword.isEmpty {
                hotSection
            } else if searching {
                LoadingStateView()
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await search() }
                }
            } else {
                resultsList
            }
        }
        .task {
            if hotWords.isEmpty {
                if let words = try? await NetEaseAPI.shared.hotSearch() {
                    hotWords = words
                }
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
                    Task { await search() }
                }
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.bottom, 8)
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
                                keyword = word
                                focused = false
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
                                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, song in
                    SongCell(song: song) {
                        player.play(songs: results, startAt: index)
                    }
                    Divider().overlay(Color.beansSecondary.opacity(0.15))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 180)
        }
        .scrollIndicators(.hidden)
    }

    private func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searching = true
        errorMessage = nil
        do {
            results = try await NetEaseAPI.shared.search(keyword: trimmed, limit: 40)
            searching = false
        } catch {
            errorMessage = error.localizedDescription
            searching = false
        }
    }
}