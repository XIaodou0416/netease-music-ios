import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 工具

func beansTimeString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - 触感反馈

enum BeansHaptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - 按压动效

struct GlassPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 背景氛围（液态玻璃需要有可采样的动态内容）

struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient.beansBackdrop
            Circle()
                .fill(Color.beansAmber.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: 150, y: -300)
            Circle()
                .fill(Color.beansSage.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: -160, y: 340)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 顶部渐隐（每个页面顶部内容淡出）

struct TopFade: View {
    var height: CGFloat = 72
    var color: Color = .beansBackground

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: color.opacity(0.95), location: 0),
                .init(color: color.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - 玻璃卡片（清透版）

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassEffectContainer {
            content()
                .padding(16)
                .glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - 封面图

struct CoverImage: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            case .empty:
                placeholder
                    .overlay {
                        ProgressView().tint(Color.beansAmber)
                    }
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.beansGlassFill)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.32, weight: .medium))
                .foregroundStyle(Color.beansSecondary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 玻璃图标按钮（清透 + 按压动效）

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(active ? Color.beansAmber : Color.beansLabel)
                .frame(width: size, height: size)
                .glassEffect(.clear, in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

// MARK: - 玻璃按钮（清透 + 按压动效）

struct GlassButton: View {
    let title: String
    var systemName: String?
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(prominent ? Color.black : Color.beansLabel)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                prominent
                    ? AnyShapeStyle(LinearGradient.beansAccent)
                    : AnyShapeStyle(.thinMaterial)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(GlassPressButtonStyle())
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    let title: String
    var trailing: String?
    var onTrailingTap: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.beansLabel)
            Spacer()
            if let trailing {
                Button {
                    onTrailingTap?()
                } label: {
                    Text(trailing)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.beansSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 空态 / 错误 / 加载

struct EmptyStateView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.beansSecondary)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.beansSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.beansSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.beansSecondary)
                .multilineTextAlignment(.center)
            GlassButton(title: "重试", systemName: "arrow.clockwise", action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LoadingStateView: View {
    var body: some View {
        ProgressView()
            .controlSize(.large)
            .tint(Color.beansAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - 二维码

struct QRCodeView: View {
    let text: String
    var size: CGFloat = 220

    var body: some View {
        if let image = Self.generateQR(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            EmptyView()
        }
    }

    private static func generateQR(from text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 当前播放指示（均衡器动效）

struct NowPlayingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.beansAmber)
                    .frame(width: 3, height: animating ? 14 : 5)
                    .animation(
                        .easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animating
                    )
            }
        }
        .frame(height: 16)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - 播放进度线（迷你播放器用）

struct ProgressLine: View {
    let progress: Double
    let duration: Double

    private var ratio: Double {
        guard duration > 0.001 else { return 0 }
        return min(max(progress / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.beansSecondary.opacity(0.25))
                Capsule()
                    .fill(Color.beansAmber)
                    .frame(width: geo.size.width * ratio)
            }
        }
    }
}