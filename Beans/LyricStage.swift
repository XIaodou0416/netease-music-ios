import SwiftUI
import UIKit

// MARK: - 封面粒子（颜色采样自封面像素，组成"粒子化封面"）
struct CoverParticle: Identifiable {
    let id: Int
    let baseX: CGFloat
    let baseY: CGFloat
    let color: Color
    var size: CGFloat
    var phase: Double
}

enum ParticleCoverSampler {
    /// 把封面缩略图采样成粒子点阵（颜色来自真实像素），密度由用户调节
    static func sample(from url: URL?, grid: Int = 40) async -> [CoverParticle] {
        guard let url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), let cg = image.cgImage else { return [] }
            let target = 96
            let scale = min(1, CGFloat(target) / CGFloat(cg.width))
            let w = max(4, Int(CGFloat(cg.width) * scale))
            let h = max(4, Int(CGFloat(cg.height) * scale))
            guard let ctx = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return [] }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let dataPtr = ctx.data else { return [] }
            let bytes = dataPtr.bindMemory(to: UInt8.self, capacity: w * h * 4)
            let stepX = max(1, w / grid)
            let stepY = max(1, h / grid)
            var particles: [CoverParticle] = []
            var idx = 0
            for y in stride(from: 0, to: h, by: stepY) {
                for x in stride(from: 0, to: w, by: stepX) {
                    let i = (y * w + x) * 4
                    let r = Double(bytes[i]) / 255.0
                    let g = Double(bytes[i + 1]) / 255.0
                    let b = Double(bytes[i + 2]) / 255.0
                    let a = Double(bytes[i + 3]) / 255.0
                    guard a > 0.06 else { continue }
                    particles.append(CoverParticle(
                        id: idx,
                        baseX: CGFloat(x) / CGFloat(w),
                        baseY: CGFloat(y) / CGFloat(h),
                        color: Color(red: r, green: g, blue: b),
                        size: 2.6 + (CGFloat(x % 7) / 7.0) * 2.6,
                        phase: Double(idx) * 0.66
                    ))
                    idx += 1
                }
            }
            return particles
        } catch {
            return []
        }
    }
}

// MARK: - 粒子化封面视图（封面粒子在 3D 空间中的正面视图）
struct ParticleCoverView: View {
    let particles: [CoverParticle]
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                for p in particles {
                    let drift = (t * 2.0 + p.phase).truncatingRemainder(dividingBy: 20)
                    let x = p.baseX * w + sin(t * 0.5 + p.phase) * 5
                    let y = p.baseY * h + cos(t * 0.42 + p.phase) * 5 - drift * 1.0
                    let r = p.size * (0.82 + sin(t * 1.1 + p.phase) * 0.18)
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(0.97)))
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - 横屏歌词舞台（全屏覆盖）
/// 3D 空间：封面粒子可手动拖动 360° 旋转（不自动转），歌词永远浮在空间正前方不动。
/// 固定横屏方向；控件竖屏方向显示在屏幕上方；左侧可展开收藏歌单列表。
struct LyricStageLandscapeView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let lyrics: [LyricLine]
    let coverURL: URL?
    let accent: Color

    /// 粒子密度（用户可调，持久化）
    @AppStorage("beans.stageParticleDensity") private var density = 40
    @State private var particles: [CoverParticle] = []
    @State private var angle: Double = 0
    @State private var dragging = false
    @State private var dragStart: Double = 0
    @State private var coverLoaded = false
    @State private var showPlaylists = false
    @State private var playlistLoading = false

    /// 二分查找当前歌词行（与歌词页一致，避免逐行扫描）
    private var currentIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= player.progress {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    private var currentLine: String {
        guard let currentIndex, lyrics.indices.contains(currentIndex) else { return "♪" }
        return lyrics[currentIndex].text.isEmpty ? "♪" : lyrics[currentIndex].text
    }

    private func fmt(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 歌词颜色：提取封面主色并提亮，保证在深色空间里看得清
    private var lyricColor: Color {
        mixedColor(accent, with: .white, amount: 0.38)
    }

    private func mixedColor(_ c: Color, with other: Color, amount: CGFloat) -> Color {
        let ui = UIColor(c)
        let ui2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ui.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let a = min(max(amount, 0), 1)
        return Color(red: r1 * (1 - a) + r2 * a, green: g1 * (1 - a) + g2 * a, blue: b1 * (1 - a) + b2 * a)
    }

    var body: some View {
        GeometryReader { geo in
            let stageW = geo.size.height
            let stageH = geo.size.width
            let coverSide = min(stageW * 0.70, stageH * 0.80)

            ZStack {
                // ---------- 3D 空间（横屏内容，固定旋转 -90°） ----------
                ZStack {
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.black.opacity(0.96), Color(red: 0.05, green: 0.04, blue: 0.10)]
                            : [Color(red: 0.10, green: 0.09, blue: 0.16), Color.black],
                        startPoint: .top, endPoint: .bottom
                    )

                    if coverLoaded {
                        // 封面粒子：只由用户拖动旋转，不自动转
                        ParticleCoverView(particles: particles, isPlaying: player.isPlaying)
                            .frame(width: coverSide, height: coverSide)
                            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                            .shadow(color: .black.opacity(0.6), radius: 40, y: 0)
                    } else {
                        ProgressView("粒子封面加载中…")
                            .tint(.white)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    // 歌词：永远在空间正前方，不随封面旋转
                    VStack(spacing: 10) {
                        Text(currentLine)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(lyricColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
                            .shadow(color: lyricColor.opacity(0.85), radius: 12)
                            .shadow(color: lyricColor.opacity(0.55), radius: 28)
                            .padding(.horizontal, 30)
                        Rectangle()
                            .fill(lyricColor.opacity(0.55))
                            .frame(width: 44, height: 3)
                            .cornerRadius(1.5)
                        HStack(spacing: 14) {
                            if lyrics.isEmpty {
                                Text("暂无歌词")
                                    .font(.system(size: 12, weight: .medium))
                            } else {
                                Text(currentIndex.map { index in "\(index + 1)/\(lyrics.count)" } ?? "1/\(lyrics.count)")
                            }
                            Text("\(fmt(player.progress)) / \(fmt(player.currentSong?.duration ?? 0))")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(width: stageW, height: stageH)
                .rotationEffect(.degrees(-90))
                .gesture(
                    // 用户手动旋转封面：拖动跟手，松手即停
                    DragGesture()
                        .onChanged { value in
                            if !dragging { dragging = true; dragStart = angle }
                            angle = (dragStart + value.translation.width * 0.5).truncatingRemainder(dividingBy: 360)
                        }
                        .onEnded { _ in
                            dragging = false
                        }
                )

                // ---------- 外层控件（竖屏方向，不旋转） ----------
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Button {
                            BeansHaptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.currentSong?.name ?? "")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(player.currentSong?.artists ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer()

                        // 收藏歌单
                        Button {
                            BeansHaptics.tap()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                showPlaylists.toggle()
                            }
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // 粒子密度滑块（常驻，随时可调）
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("粒子密度")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(density) × \(density)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(density) },
                                set: { density = Int($0) }
                            ),
                            in: 10...60,
                            step: 2
                        )
                        .tint(.white)
                    }
                    .padding(14)
                    .frame(maxWidth: 340)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 8)

                // ---------- 左侧收藏歌单面板 ----------
                if showPlaylists {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("收藏歌单")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.top, 8)
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 8) {
                                    if auth.playlists.isEmpty {
                                        Text("暂无收藏歌单")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .padding(.top, 24)
                                    } else {
                                        ForEach(auth.playlists) { playlist in
                                            Button {
                                                BeansHaptics.tap()
                                                playPlaylist(playlist)
                                            } label: {
                                                HStack(spacing: 10) {
                                                    CoverImage(url: playlist.coverURL, size: 40, cornerRadius: 8)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(playlist.name)
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundStyle(.white)
                                                            .lineLimit(1)
                                                        Text("\(playlist.trackCount) 首")
                                                            .font(.system(size: 10))
                                                            .foregroundStyle(.white.opacity(0.5))
                                                    }
                                                    Spacer()
                                                    Image(systemName: "play.circle")
                                                        .font(.system(size: 14))
                                                        .foregroundStyle(.white.opacity(0.6))
                                                }
                                                .padding(8)
                                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .padding(12)
                        .frame(width: 250, alignment: .leading)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                        }
                        .padding(.vertical, 70)
                        .padding(.leading, 14)
                        Spacer()
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .task(id: density) {
            coverLoaded = false
            particles = await ParticleCoverSampler.sample(from: coverURL, grid: density)
            coverLoaded = true
        }
    }

    private func playPlaylist(_ playlist: Playlist) {
        playlistLoading = true
        Task {
            let tracks = (try? await NetEaseAPI.shared.playlistTracks(id: playlist.id)) ?? []
            playlistLoading = false
            guard !tracks.isEmpty else {
                BeansHaptics.tap()
                return
            }
            player.play(songs: tracks, startAt: 0)
            BeansHaptics.success()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showPlaylists = false
            }
        }
    }
}
