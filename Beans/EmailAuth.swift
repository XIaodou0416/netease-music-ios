import SwiftUI
import CryptoKit

// MARK: - 邮箱账号（本地演示账号系统）
// 无后端服务器：账号密码加盐哈希后保存在本机 UserDefaults，
// 仅用于“进入软件需先注册/登录”的本地演示，不涉及真实邮件验证。

final class EmailAuthStore: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentEmail: String?

    private let defaults = UserDefaults.standard
    private let accountsKey = "beans.email.accounts"
    private let currentKey = "beans.email.current"
    private let salt = "beans.email.salt.v1"

    private var accounts: [String: String] {
        get { defaults.dictionary(forKey: accountsKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: accountsKey) }
    }

    init() {
        if let email = defaults.string(forKey: currentKey),
           accounts[Self.normalize(email)] != nil {
            currentEmail = email
            isLoggedIn = true
        }
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError, Equatable {
        case invalidEmail
        case weakPassword
        case emailTaken
        case wrongCredentials

        var errorDescription: String? {
            switch self {
            case .invalidEmail: return "请输入有效的邮箱地址"
            case .weakPassword: return "密码至少需要 6 位"
            case .emailTaken: return "该邮箱已注册，请直接登录"
            case .wrongCredentials: return "邮箱或密码不正确"
            }
        }
    }

    @discardableResult
    func register(email: String, password: String) -> Result<Void, AuthError> {
        let e = Self.normalize(email)
        guard e.contains("@"), e.contains("."), e.count > 5 else { return .failure(.invalidEmail) }
        guard password.count >= 6 else { return .failure(.weakPassword) }
        guard accounts[e] == nil else { return .failure(.emailTaken) }
        var store = accounts
        store[e] = hash(password)
        accounts = store
        return completeLogin(email: e, password: password)
    }

    @discardableResult
    func login(email: String, password: String) -> Result<Void, AuthError> {
        let e = Self.normalize(email)
        guard let stored = accounts[e], stored == hash(password) else {
            return .failure(.wrongCredentials)
        }
        return completeLogin(email: e, password: password)
    }

    private func completeLogin(email: String, password: String) -> Result<Void, AuthError> {
        currentEmail = email
        isLoggedIn = true
        defaults.set(email, forKey: currentKey)
        return .success(())
    }

    func logout() {
        isLoggedIn = false
        currentEmail = nil
        defaults.removeObject(forKey: currentKey)
    }
}

// MARK: - 邮箱注册 / 登录页（全屏液态玻璃，未登录时拦截整个 App）

struct EmailAuthView: View {
    @EnvironmentObject private var emailAuth: EmailAuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isRegister = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(LinearGradient.beansAccent)
                Text("Beans")
                    .font(BeansFont.appFont(34, .bold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.top, 10)
                Text(isRegister ? "注册邮箱账号" : "登录邮箱账号")
                    .font(BeansFont.appFont(14))
                    .foregroundStyle(Color.beansSecondary)
                    .padding(.top, 4)

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "at")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.beansSecondary)
                        TextField("邮箱地址", text: $email)
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background { fieldGlass(20) }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.beansSecondary)
                        Group {
                            if showPassword {
                                TextField("密码（至少 6 位）", text: $password)
                            } else {
                                SecureField("密码（至少 6 位）", text: $password)
                            }
                        }
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        Button {
                            BeansHaptics.select()
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.beansSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background { fieldGlass(20) }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(isRegister ? "注册并进入" : "登录并进入")
                            .font(BeansFont.appFont(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LinearGradient.beansAccent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(GlassPressButtonStyle(scale: 0.96))
                    .padding(.top, 4)

                    Button {
                        BeansHaptics.select()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isRegister.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isRegister ? "已有账号？去登录" : "没有账号？立即注册")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background {
                    GlassEffectContainer {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .beansCardShadow(radius: 16, y: 8)
                .padding(.horizontal, 26)
                .padding(.top, 30)

                Text("本地演示账号 · 数据仅保存在本机，不发送邮件验证")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansSecondary.opacity(0.85))
                    .padding(.top, 18)
                Spacer(minLength: 30)
            }
        }
        .ignoresSafeArea()
        .onChange(of: emailAuth.isLoggedIn) { _, loggedIn in
            if loggedIn { BeansHaptics.success() }
        }
    }

    private func fieldGlass(_ radius: CGFloat) -> some View {
        GlassEffectContainer {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.clear)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    private func submit() {
        BeansHaptics.tap()
        let result = isRegister
            ? emailAuth.register(email: email, password: password)
            : emailAuth.login(email: email, password: password)
        switch result {
        case .success:
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.errorDescription
            BeansHaptics.medium()
        }
    }
}
