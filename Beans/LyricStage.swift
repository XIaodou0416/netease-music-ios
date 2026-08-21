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
    /// 把封面缩略图采样成粒子点阵（颜色来自真实像素，形成粒子化封面）
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

// MARK: - 粒子化封面视图（可被 rotation3DEffect 做 360° 旋转）
struct ParticleCoverView: View {
    let particles: [CoverParticle]
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                // 粒子按封面像素排列，播放时缓慢漂浮，形成"粒子化封面"
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
/// 竖屏触发时内容自动旋转 90° 以横屏显示；封面粒子 360° 旋转，歌词反向补偿始终保持在正面。
struct LyricStageLandscapeView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let lyrics: [LyricLine]
    let coverURL: URL?

    @State private var particles: [CoverParticle] = []
    @State private var angle: Double = 0
    @State private var autoRotate = true
    @State private var dragging = false
    @State private var dragStart: Double = 0
    @State private var coverLoaded = false

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

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

    var body: some View {
        GeometryReader { geo in
            // 固定横屏方向：无论手机如何放置，画面始终同一个方向
            let stageW = geo.size.height
            let stageH = geo.size.width
            let coverSide = min(stageW * 0.72, stageH * 0.86)

            ZStack {
                // 深色底 + 封面主色辉光
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black.opacity(0.96), Color(red: 0.05, green: 0.04, blue: 0.10)]
                        : [Color(red: 0.10, green: 0.09, blue: 0.16), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if coverLoaded {
                    // 粒子化封面，绕 Y 轴 360° 旋转
                    ParticleCoverView(particles: particles, isPlaying: player.isPlaying)
                        .frame(width: coverSide, height: coverSide)
                        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 0)
                } else {
                    ProgressView("粒子封面加载中…")
                        .tint(.white)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // 当前歌词：反向补偿旋转，始终保持在正面
                VStack(spacing: 10) {
                    Text(currentLine)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.85), radius: 6, y: 2)
                        .shadow(color: Color.white.opacity(0.35), radius: 14)
                        .padding(.horizontal, 24)
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 44, height: 3)
                        .cornerRadius(1.5)
                    Text(currentIndex.map { index in "\(index + 1)/\(lyrics.count)" } ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)

                // 顶部操作条
                VStack {
                    HStack {
                        Button {
                            BeansHaptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(player.currentSong?.name ?? "")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            BeansHaptics.tap()
                            withAnimation(.linear(duration: 0.3)) { angle = (angle + 180).truncatingRemainder(dividingBy: 360) }
                        } label: {
                            Image(systemName: "rotate.3d")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    Spacer()
                    Text("左右拖动旋转封面 · 单击歌词跳转")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 14)
                }
                .frame(width: stageW, height: stageH)
            }
            .frame(width: stageW, height: stageH)
            .rotationEffect(.degrees(-90))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            if autoRotate && !dragging {
                angle = (angle + 0.6).truncatingRemainder(dividingBy: 360)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !dragging { dragging = true; dragStart = angle }
                    autoRotate = false
                    angle = (dragStart + value.translation.width * 0.4).truncatingRemainder(dividingBy: 360)
                }
                .onEnded { _ in
                    dragging = false
                    autoRotate = true
                }
        )
        .onTapGesture {
            guard let currentIndex else { return }
            BeansHaptics.tap()
            player.seek(to: lyrics[currentIndex].time)
        }
        .task {
            particles = await ParticleCoverSampler.sample(from: coverURL)
            coverLoaded = true
        }
    }
}
