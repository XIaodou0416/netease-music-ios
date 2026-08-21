import SwiftUI
import UIKit

// MARK: - 沉浸视觉（Mineradio 风格新样式）开关
/// 全局持久化：默认关闭（旧样式）。开启后播放页粒子背景、歌词舞台、3D 歌单架生效。
/// 关闭时整套新视觉代码不参与布局，零性能开销。
enum ImmersiveVisual {
    static let key = "beans.immersiveVisual"
    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - 节拍脉冲（时间驱动，不接音频管线：零改动播放引擎、零性能风险）
enum ImmersiveBeat {
    /// 0~1 的脉冲值，bpm 约 78，模拟随音乐节奏波动
    static func pulse(at time: TimeInterval, offset: Double = 0, bpm: Double = 78) -> CGFloat {
        let phase = ((time + offset) * bpm / 60).truncatingRemainder(dividingBy: 1)
        let p = 1 - phase * 2.6
        return min(1, max(0, CGFloat(p)))
    }
}

// MARK: - 播放页粒子背景（Canvas 绘制，48 粒子 + 2 氛围光斑；暂停时静止省电）
struct ImmersiveParticleBackground: View {
    let accent: Color
    let secondary: Color
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

                // 氛围光斑（大径向渐变圆，跟随节拍呼吸）
                for i in 0..<2 {
                    let cx = rand(i, 1) * w
                    let cy = rand(i, 2) * h
                    let pulse = ImmersiveBeat.pulse(at: t, offset: Double(i) * 0.35)
                    let radius = (isPlaying ? 90 + pulse * 40 : 70) + w * 0.08
                    let grad = Gradient(colors: [
                        (i == 0 ? accent : secondary).opacity(isPlaying ? 0.16 + pulse * 0.10 : 0.10),
                        (i == 0 ? accent : secondary).opacity(0.0)
                    ])
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(grad, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: radius)
                    )
                }

                // 扫描光带（斜向流动，增强炫酷感）
                let bandT = (t * 0.05).truncatingRemainder(dividingBy: 1.0)
                let bandX = CGFloat(bandT) * w * 1.6 - w * 0.3
                let band = Path(CGRect(x: bandX, y: -h * 0.3, width: w * 0.22, height: h * 1.6))
                context.fill(
                    band,
                    with: .linearGradient(
                        Gradient(colors: [accent.opacity(0), accent.opacity(isPlaying ? 0.10 : 0.04), accent.opacity(0)]),
                        startPoint: CGPoint(x: bandX, y: 0),
                        endPoint: CGPoint(x: bandX + w * 0.22, y: h)
                    )
                )

                // 粒子：播放时缓慢漂移 + 节拍扩散；暂停时静止
                for i in 0..<72 {
                    let px = rand(i, 3)
                    let py = rand(i, 4)
                    let baseX = px * w
                    let baseY = py * h
                    let drift = (t * 6 + Double(i) * 1.3).truncatingRemainder(dividingBy: 24)
                    let x = baseX + sin(t * 0.35 + Double(i) * 2.1) * 16 + (isPlaying ? sin(drift) * 10 : 0)
                    let y = baseY + cos(t * 0.30 + Double(i) * 1.7) * 12 - (isPlaying ? drift * 2.2 : 0)
                    let pulse = ImmersiveBeat.pulse(at: t, offset: Double(i) * 0.045)
                    let radius = 1.2 + py * 3.0 + (isPlaying ? pulse * 2.0 : 0)
                    let color = (i % 3 == 0 ? accent : secondary)
                        .opacity(0.08 + py * 0.20 + (isPlaying ? pulse * 0.08 : 0))
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }

                // 星点（高亮小十字闪光）
                for i in 0..<8 {
                    let sx = rand(i, 7) * w
                    let sy = rand(i, 8) * h
                    let twinkle = 0.5 + 0.5 * sin(t * 1.6 + Double(i) * 1.3)
                    let star = 1.2 + CGFloat(twinkle) * (isPlaying ? 2.2 : 0.8)
                    let sc = Color.white.opacity(0.35 + CGFloat(twinkle) * (isPlaying ? 0.45 : 0.15))
                    let cx = sx + sin(t * 0.6 + Double(i)) * 12
                    let cy = sy + cos(t * 0.5 + Double(i) * 1.4) * 10
                    var path = Path()
                    path.move(to: CGPoint(x: cx - star * 2.2, y: cy))
                    path.addLine(to: CGPoint(x: cx + star * 2.2, y: cy))
                    path.move(to: CGPoint(x: cx, y: cy - star * 2.2))
                    path.addLine(to: CGPoint(x: cx, y: cy + star * 2.2))
                    context.stroke(path, with: .color(sc), lineWidth: 1.1)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

// MARK: - 3D 歌单架（歌单广场新样式：横滑卡片带 3D 倾斜）
struct ImmersivePlaylistShelf: View {
    let playlists: [Playlist]
    let onTap: (Playlist) -> Void
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                Button {
                    BeansHaptics.tap()
                    onTap(playlist)
                } label: {
                    VStack(spacing: 10) {
                        CoverImage(url: playlist.coverURL, size: 150, cornerRadius: 22)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
                        Text(playlist.name)
                            .font(BeansFont.appFont(12, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                            .padding(.horizontal, 24)
                    }
                }
                .buttonStyle(.plain)
                .rotation3DEffect(
                    .degrees(Double(index - page) * 10),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.6
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 218)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: page)
    }
}
