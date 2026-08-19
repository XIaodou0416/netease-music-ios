import SwiftUI
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var qrImage: UIImage?
    @State private var statusText = "正在获取二维码…"
    @State private var isLoading = false
    @State private var pollTask: Task<Void, Never>?
    @State private var unikey = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var errorDetail: String?
    @State private var qrCreatedAt = Date()
    @State private var didAutoRefresh = false

    /// 二维码密钥有效期约 60~120 秒，超时后自动刷新一次（再超时则提示手动刷新）
    private let qrTTL: TimeInterval = 75

    var body: some View {
        // 修复：登录页以 sheet 弹出，需要独立玻璃采样容器，否则内部玻璃组件空白/糊块
        GlassEffectContainer {
            ZStack {
                Color.beansBackground.ignoresSafeArea()
                LinearGradient(colors: [Color.beansAmber.opacity(0.16), .clear], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    header
                    Spacer(minLength: 8)
                    qrSection
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    if isLoading {
                        ProgressView().tint(Color.beansAmber)
                    }
                    Button {
                        Task { await startLogin() }
                    } label: {
                        Text(qrImage == nil ? "获取二维码" : "刷新二维码")
                            .font(.headline)
                            .foregroundStyle(Color.beansBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Color.beansAmber))
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    Spacer(minLength: 24)
                }
                .padding(.top, 14)
            }
        }
        .alert("出错了", isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        // 关闭/取消登录时取消轮询，避免后台继续请求（用户取消扫码的回调）
        .onDisappear { pollTask?.cancel() }
        .task { await startLogin() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("登录网易云")
                    .font(.title2.bold())
                    .foregroundStyle(Color.beansLabel)
                Text("扫码登录，同步你的收藏与歌单")
                    .font(.footnote)
                    .foregroundStyle(Color.beansSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.beansSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var qrSection: some View {
        Group {
            if let errorDetail {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(Color.beansAmber)
                    Text(errorDetail)
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                // 修复：固定高度占位改为自适应，避免小屏/大字号下溢出错位
                .frame(maxWidth: 280, minHeight: 200, maxHeight: 240)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        Group {
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .padding(14)
                    .background(Color.beansGlassFill)
                    .glassEffect(.regular)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundStyle(Color.beansAmber)
                    Text("二维码会出现在这里")
                        .font(.footnote)
                        .foregroundStyle(Color.beansSecondary)
                }
                .frame(maxWidth: 244, minHeight: 244, maxHeight: 250)
                .frame(maxWidth: .infinity)
                .background(Color.beansGlassFill)
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }

    private func startLogin(auto: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        // 手动刷新才重置自动刷新标记；自动刷新保留标记，避免无限自刷
        if !auto { didAutoRefresh = false }
        do {
            let key = try await NetEaseAPI.shared.qrKey()
            unikey = key
            qrCreatedAt = Date()
            let loginURL = NetEaseAPI.shared.qrLoginURL(key: key)
            qrImage = QRGenerator.image(for: loginURL)
            statusText = "用网易云 App 扫一扫，然后在手机上确认"
            pollTask?.cancel()
            pollTask = Task { await pollLogin() }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
            statusText = "获取二维码失败，点下方重试"
            errorDetail = error.localizedDescription
        }
    }

    private func pollLogin() async {
        while !Task.isCancelled {
            // 超时兜底：轮询期间二维码超时未确认，自动刷新二维码（只自动一次）
            if !didAutoRefresh && Date().timeIntervalSince(qrCreatedAt) > qrTTL {
                await MainActor.run { statusText = "二维码已过期，正在自动刷新…" }
                didAutoRefresh = true
                await startLogin(auto: true)
                return
            }
            do {
                let code = try await NetEaseAPI.shared.qrCheck(key: unikey)
                switch code {
                case 800:
                    // 服务端判定二维码过期：自动刷新一次，之后提示手动刷新
                    if !didAutoRefresh {
                        await MainActor.run { statusText = "二维码已过期，正在自动刷新…" }
                        didAutoRefresh = true
                        await startLogin(auto: true)
                    } else {
                        await MainActor.run { statusText = "二维码已过期，点下方手动刷新" }
                    }
                    return
                case 802:
                    await MainActor.run { statusText = "已扫描，请在手机上确认登录" }
                case 803:
                    await MainActor.run { statusText = "登录成功，正在泡你的音乐…" }
                    do {
                        try await auth.finishLogin()
                        await MainActor.run { dismiss() }
                    } catch {
                        await MainActor.run {
                            alertMessage = "登录已确认，但加载资料失败：\(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                    return
                default:
                    await MainActor.run { statusText = "等待扫码…" }
                }
            } catch {
                await MainActor.run { statusText = "网络不稳定，正在重试…" }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}

enum QRGenerator {
    static func image(for string: String, size: CGFloat = 220) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = size / max(output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}