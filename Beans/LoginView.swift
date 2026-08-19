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

    var body: some View {
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
        .alert("出错了", isPresented: $showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
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
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 216, height: 216)
                    .padding(14)
                    .glassEffect(.regular)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: 244, height: 244)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "qrcode")
                                .font(.largeTitle)
                                .foregroundStyle(Color.beansAmber)
                            Text("二维码会出现在这里")
                                .font(.footnote)
                                .foregroundStyle(Color.beansSecondary)
                        }
                    )
            }
        }
    }

    private func startLogin() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let key = try await NetEaseAPI.shared.qrKey()
            unikey = key
            let loginURL = NetEaseAPI.shared.qrLoginURL(key: key)
            qrImage = QRGenerator.image(for: loginURL)
            statusText = "用网易云 App 扫一扫，然后在手机上确认"
            pollTask?.cancel()
            pollTask = Task { await pollLogin() }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
            statusText = "获取二维码失败，点下方重试"
        }
    }

    private func pollLogin() async {
        while !Task.isCancelled {
            do {
                let code = try await NetEaseAPI.shared.qrCheck(key: unikey)
                switch code {
                case 800:
                    await MainActor.run { statusText = "二维码已过期，点下方刷新" }
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
        return UIImage(ciImage: scaled)
    }
}