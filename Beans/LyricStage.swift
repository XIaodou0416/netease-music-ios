import SwiftUI
import UIKit

// MARK: - 横屏歌词舞台渲染风格（用户可自主选择，持久化记忆）
enum StageRenderStyle: String, CaseIterable, Identifiable {
    case particles = "粒子封面"
    case pixel = "像素封面"
    case nebula = "星云漩涡"
    case waves = "声浪律动"
    case glow = "光晕呼吸"
    case meteor = "流星拖尾"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .particles: return "sparkles"
        case .pixel: return "square.grid.3x3"
        case .nebula: return "circle.hexagongrid"
        case .waves: return "waveform"
        case .glow: return "circle.circle"
        case .meteor: return "bolt.horizontal"
        }
    }
}

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

// MARK: - 粒子化封面视图（粒子封面风格：可被 rotation3DEffect 做 360° 旋转）
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

// MARK: - 其他风格全屏背景渲染（像素 / 星云 / 声浪 / 光晕 / 流星）
struct StageAmbientView: View {
    let style: StageRenderStyle
    let particles: [CoverParticle]
    let accent: Color
    let isPlaying: Bool

    private func rand(_ i: Int, _ seed: Double) -> Double {
        let v = sin(Double(i) * 127.1 + seed * 311.7) * 43758.5453
        return v - floor(v)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                let pulse = min(1, max(0, 1 - (((t * 78 / 60).truncatingRemainder(dividingBy: 1)) * 2.6)))

                switch style {
                case .pixel:
                    // 像素封面：大色块拼出封面
                    let blockW = w / 22, blockH = h / 15
                    for p in particles {
                        let bx = p.baseX * w + sin(t * 0.4 + p.phase) * 3
                        let by = p.baseY * h + cos(t * 0.35 + p.phase) * 3
                        let rect = CGRect(x: bx - blockW / 2, y: by - blockH / 2, width: blockW * 1.15, height: blockH * 1.15)
                        context.fill(Path(rect), with: .color(p.color.opacity(0.9)))
                    }
                case .nebula:
                    // 星云漩涡：三条螺旋星带，随时间旋转
                    let spokes = 3
                    for s in 0..<spokes {
                        let spin = t * (0.28 + Double(s) * 0.06) + Double(s) * 2.094
                        let baseAngle = spin
                        let cx = w * 0.5, cy = h * 0.5
                        let maxR = min(w, h) * 0.48
                        for i in 0..<90 {
                            let r = maxR * Double(i) / 90.0
                            let a = baseAngle + r * 0.006
                            let x = cx + CGFloat(cos(a) * r)
                            let y = cy + CGFloat(sin(a) * r) * 0.9
                            let fade = 1.0 - Double(i) / 90.0
                            let col = s == 0 ? accent : (s == 1 ? accent.opacity(0.6) : Color.white.opacity(0.35))
                            let rr = 2.4 * CGFloat(fade) + CGFloat(pulse) * 1.4
                            let rect = CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)
                            context.fill(Path(ellipseIn: rect), with: .color(col.opacity(0.5 * fade + 0.2)))
                        }
                    }
                case .waves:
                    // 声浪律动：四条波形，峰谷随节拍起伏
                    let rows: [CGFloat] = [0.30, 0.44, 0.58, 0.72]
                    for (ri, row) in rows.enumerated() {
                        let cy = h * row
                        let amp = 14 + CGFloat(pulse) * 20 + CGFloat(ri) * 4
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: cy))
                        let step = w / 60
                        for x in stride(from: CGFloat(0), through: w, by: step) {
                            let y = cy + sin(x * 0.018 + t * (1.6 + Double(ri) * 0.4)) * amp
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        let grad = Gradient(colors: [accent.opacity(0.0), accent.opacity(0.75), accent.opacity(0.0)])
                        context.stroke(path, with: .linearGradient(grad, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: w, y: 0)), lineWidth: 3.2)
                    }
                case .glow:
                    // 光晕呼吸：大光斑 + 光环 + 星点
                    let cx = w * 0.5, cy = h * 0.5
                    let maxR = min(w, h) * 0.42
                    let radius = maxR * (0.85 + CGFloat(pulse) * 0.25)
                    let grad = Gradient(colors: [
                        accent.opacity(0.55 + Double(pulse) * 0.2),
                        accent.opacity(0.18),
                        accent.opacity(0.0)
                    ])
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(grad, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: radius)
                    )
                    for i in 0..<2 {
                        let ringR = maxR * (0.55 + CGFloat(i) * 0.22 + CGFloat(pulse) * 0.15)
                        let ring = Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2))
                        context.stroke(ring, with: .color(accent.opacity(0.35 + Double(pulse) * 0.2)), lineWidth: 1.6)
                    }
                    for i in 0..<40 {
                        let sx = rand(i, 1) * w
                        let sy = rand(i, 2) * h
                        let tw = 0.5 + 0.5 * sin(t * 1.5 + Double(i) * 1.7)
                        let star = 1.0 + CGFloat(tw) * 2.2
                        let cx2 = sx + sin(t * 0.5 + Double(i)) * 14
                        let cy2 = sy + cos(t * 0.45 + Double(i) * 1.3) * 12
                        var sp = Path()
                        sp.move(to: CGPoint(x: cx2 - star * 2, y: cy2))
                        sp.addLine(to: CGPoint(x: cx2 + star * 2, y: cy2))
                        sp.move(to: CGPoint(x: cx2, y: cy2 - star * 2))
                        sp.addLine(to: CGPoint(x: cx2, y: cy2 + star * 2))
                        context.stroke(sp, with: .color(.white.opacity(0.25 + tw * 0.5)), lineWidth: 1.1)
                    }
                case .meteor:
                    // 流星拖尾：粒子沿轨道飞行，带渐变尾巴
                    for i in 0..<14 {
                        let speed = 0.02 + Double(i % 5) * 0.006
                        let dist = ((t * speed + Double(i) * 0.73).truncatingRemainder(dividingBy: 1.0))
                        let angle = Double(i) * 0.45
                        let cx = w * 0.5 + CGFloat(cos(angle) * (dist * 1.3 - 0.15)) * w * 0.6
                        let cy = h * 0.5 + CGFloat(sin(angle) * (dist * 1.3 - 0.15)) * h * 0.6
                        let tail = 26.0 + Double(pulse) * 14
                        let tx = cx - CGFloat(cos(angle)) * CGFloat(tail)
                        let ty = cy - CGFloat(sin(angle)) * CGFloat(tail)
                        var mp = Path()
                        mp.move(to: CGPoint(x: tx, y: ty))
                        mp.addLine(to: CGPoint(x: cx, y: cy))
                        let col = i % 3 == 0 ? Color.white : accent
                        context.stroke(mp, with: .color(col.opacity(0.75)), lineWidth: 1.8)
                        let headR = 2.6 + CGFloat(pulse) * 1.6
                        context.fill(
                            Path(ellipseIn: CGRect(x: cx - headR, y: cy - headR, width: headR * 2, height: headR * 2)),
                            with: .color(.white.opacity(0.95))
                        )
                    }
                case .particles:
                    break
                }
            }
        }
        .drawingGroup()
    }
}

// MARK: - 横屏歌词舞台（全屏覆盖）
/// 固定横屏方向；粒子封面可 360° 旋转、歌词反向补偿始终保持在正面；支持多种渲染风格。
struct LyricStageLandscapeView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let lyrics: [LyricLine]
    let coverURL: URL?
    let accent: Color

    @AppStorage("beans.stageRenderStyle") private var styleRaw = StageRenderStyle.particles.rawValue
    @State private var particles: [CoverParticle] = []
    @State private var angle: Double = 0
    @State private var autoRotate = true
    @State private var dragging = false
    @State private var dragStart: Double = 0
    @State private var coverLoaded = false

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private var renderStyle: StageRenderStyle {
        StageRenderStyle(rawValue: styleRaw) ?? .particles
    }

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
                    if renderStyle == .particles {
                        // 粒子化封面，绕 Y 轴 360° 旋转
                        ParticleCoverView(particles: particles, isPlaying: player.isPlaying)
                            .frame(width: coverSide, height: coverSide)
                            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                            .shadow(color: .black.opacity(0.6), radius: 40, y: 0)
                    } else {
                        // 其他风格：全屏背景渲染
                        StageAmbientView(style: renderStyle, particles: particles, accent: accent, isPlaying: player.isPlaying)
                    }
                } else {
                    ProgressView("粒子封面加载中…")
                        .tint(.white)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // 当前歌词：粒子封面风格反向补偿旋转，其余风格固定正面
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
                .rotation3DEffect(.degrees(renderStyle == .particles ? -angle : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)

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
                        Menu {
                            ForEach(StageRenderStyle.allCases) { st in
                                Button {
                                    BeansHaptics.select()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        styleRaw = st.rawValue
                                    }
                                } label: {
                                    if st == renderStyle {
                                        Label(st.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(st.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                        }
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
                    Text("\(renderStyle.rawValue) · 左右拖动旋转封面 · 单击歌词跳转")
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
            if autoRotate && !dragging && renderStyle == .particles {
                angle = (angle + 0.6).truncatingRemainder(dividingBy: 360)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard renderStyle == .particles else { return }
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
