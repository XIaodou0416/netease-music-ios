import SwiftUI
import UIKit

// MARK: - 播放器氛围光晕（背景动态渐变 + 浮尘）
/// 封面主色/次色两个光斑缓慢漂移 + 呼吸，配极淡浮尘粒子。
/// 只画径向渐变与圆形，无 AsyncImage，暂停时完全静止，不耗电。
struct AmbientGlowView: View {
    let accent: Color
    let secondary: Color
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height

                // 主色光斑（缓慢漂移 + 呼吸）
                let cx = w * (0.5 + 0.18 * sin(t * 0.25))
                let cy = h * (0.30 + 0.12 * cos(t * 0.20))
                let r1 = min(w, h) * 0.55
                let breathe = 0.85 + 0.15 * sin(t * 1.1)
                let g1 = Gradient(colors: [accent.opacity(0.16 * breathe), accent.opacity(0)])
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - r1, y: cy - r1, width: r1 * 2, height: r1 * 2)),
                    with: .radialGradient(g1, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r1)
                )

                // 次色光斑（反向漂移）
                let cx2 = w * (0.5 + 0.20 * cos(t * 0.22 + 1.7))
                let cy2 = h * (0.72 + 0.12 * sin(t * 0.18 + 2.3))
                let r2 = min(w, h) * 0.42
                let g2 = Gradient(colors: [secondary.opacity(0.13), secondary.opacity(0)])
                context.fill(
                    Path(ellipseIn: CGRect(x: cx2 - r2, y: cy2 - r2, width: r2 * 2, height: r2 * 2)),
                    with: .radialGradient(g2, center: CGPoint(x: cx2, y: cy2), startRadius: 0, endRadius: r2)
                )

                // 浮尘微粒（极淡，缓慢环游）
                for i in 0..<26 {
                    let px = w * (0.5 + 0.45 * sin(Double(i) * 2.4 + t * 0.12))
                    let py = h * (0.5 + 0.42 * cos(Double(i) * 1.8 + t * 0.10))
                    let tw = 0.5 + 0.5 * sin(t * 0.9 + Double(i) * 1.7)
                    let r = 1.2 + 1.6 * tw
                    let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05 + 0.06 * tw)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
    }
}
