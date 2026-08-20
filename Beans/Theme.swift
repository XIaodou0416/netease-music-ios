import SwiftUI
import UIKit

// MARK: - 动态主题色（跟随系统外观或手动切换）

extension UIColor {
    static func beansDynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    static let beansBackground = beansDynamic(
        light: UIColor(red: 0.949, green: 0.949, blue: 0.961, alpha: 1),  // #F2F2F7
        dark: UIColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1)    // #0A0A0C
    )
    static let beansCard = beansDynamic(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)    // #1C1C1E
    )
    static let beansLabel = beansDynamic(
        light: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    )
    static let beansSecondary = beansDynamic(
        light: UIColor(red: 0.424, green: 0.424, blue: 0.439, alpha: 1),  // #6C6C70
        dark: UIColor(red: 0.596, green: 0.596, blue: 0.624, alpha: 1)    // #98989F
    )
    /// 全局着色（跟随配色主题：浅色用深色调保证对比度，深色用亮色调保证可读性）
    static var beansAmber: UIColor {
        if let custom = ThemeStore.shared.customAccentHex, let c = UIColor(hex: custom) {
            return beansDynamic(light: c.shaded(0.25), dark: c)
        }
        let accent = ThemeStore.shared.accent
        return beansDynamic(light: accent.tintLight, dark: accent.tintDark)
    }
    static let beansSage = beansDynamic(
        light: UIColor(red: 0.384, green: 0.482, blue: 0.310, alpha: 1),
        dark: UIColor(red: 0.560, green: 0.650, blue: 0.480, alpha: 1)
    )
    /// 液态玻璃基底填充：修复 `.glassEffect` 配 `Color.clear` 时玻璃无内容可采样、
    /// 渲染成灰糊块/模糊失效的问题（玻璃效果需要一个非透明基底色）。
    static let beansGlassFill = beansDynamic(
        light: UIColor(white: 0.96, alpha: 0.55),
        dark: UIColor(white: 0.07, alpha: 0.55)
    )
}

extension Color {
    static let beansBackground = Color(uiColor: .beansBackground)
    static let beansCard = Color(uiColor: .beansCard)
    static let beansLabel = Color(uiColor: .beansLabel)
    static let beansSecondary = Color(uiColor: .beansSecondary)
    /// 全局着色：跟随当前配色主题即时变化（所有页面统一生效）
    static var beansAmber: Color { Color(uiColor: .beansAmber) }
    static let beansSage = Color(uiColor: .beansSage)
    static let beansGlassFill = Color(uiColor: .beansGlassFill)
    /// 当前配色主题的高亮色（播放器进度点 / 光斑 / 歌词高亮等）
    static var beansHighlight: Color {
        ThemeStore.shared.customAccent ?? AccentTheme.current.highlight
    }
}

// MARK: - 主题偏好

enum BeansThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

// MARK: - 配色主题（多套配色，可在「我的 → 外观」中切换；全局统一生效）

enum BeansAccent: String, CaseIterable, Identifiable {
    case amber = "琥珀暖金"
    case mint = "青碧湖绿"
    case pink = "樱粉"
    case sky = "星蓝"
    case violet = "罗兰紫"

    var id: String { rawValue }

    /// 渐变强调色（播放键 / 进度条 / 玻璃光晕）
    var gradientColors: [Color] {
        switch self {
        case .amber:
            return [Color(red: 0.949, green: 0.639, blue: 0.235), Color(red: 0.753, green: 0.478, blue: 0.039)]
        case .mint:
            return [Color(red: 0.42, green: 0.78, blue: 0.62), Color(red: 0.16, green: 0.55, blue: 0.42)]
        case .pink:
            return [Color(red: 0.96, green: 0.56, blue: 0.70), Color(red: 0.82, green: 0.37, blue: 0.56)]
        case .sky:
            return [Color(red: 0.39, green: 0.71, blue: 0.96), Color(red: 0.23, green: 0.48, blue: 0.84)]
        case .violet:
            return [Color(red: 0.70, green: 0.62, blue: 0.86), Color(red: 0.49, green: 0.34, blue: 0.76)]
        }
    }

    /// 高亮色（渐变首色，用于光斑 / 进度点 / 歌词高亮）
    var highlight: Color {
        gradientColors[0]
    }

    /// 常规着色（图标 / 文字）浅色模式版本：深色调保证浅色背景对比度
    var tintLight: UIColor {
        switch self {
        case .amber: return UIColor(red: 0.72, green: 0.44, blue: 0.03, alpha: 1)   // 深琥珀
        case .mint: return UIColor(red: 0.15, green: 0.53, blue: 0.39, alpha: 1)    // 深湖绿
        case .pink: return UIColor(red: 0.78, green: 0.33, blue: 0.53, alpha: 1)    // 深樱粉
        case .sky: return UIColor(red: 0.20, green: 0.48, blue: 0.84, alpha: 1)     // 深星蓝
        case .violet: return UIColor(red: 0.46, green: 0.34, blue: 0.77, alpha: 1)  // 深罗兰
        }
    }

    /// 常规着色（图标 / 文字）深色模式版本：亮色调保证深色背景对比度
    var tintDark: UIColor {
        switch self {
        case .amber: return UIColor(red: 0.96, green: 0.70, blue: 0.35, alpha: 1)
        case .mint: return UIColor(red: 0.45, green: 0.80, blue: 0.64, alpha: 1)
        case .pink: return UIColor(red: 0.97, green: 0.60, blue: 0.74, alpha: 1)
        case .sky: return UIColor(red: 0.45, green: 0.72, blue: 0.98, alpha: 1)
        case .violet: return UIColor(red: 0.71, green: 0.62, blue: 0.92, alpha: 1)
        }
    }
}

// MARK: - 全局主题（ObservableObject：一处修改，全 App 即时联动）

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    /// 当前配色主题（@Published：切换后所有观察视图立即重绘）
    @Published var accent: BeansAccent
    /// 自定义全局强调色（色盘任选，nil 表示使用预设主题）
    @Published var customAccentHex: String?
    /// 自定义背景色（色盘任选，空串表示默认渐变背景）
    @Published var backgroundHex: String = ""
    /// 自定义背景是否同步到搜索 / 音乐库 / 我的等全部页面
    @Published var backgroundSyncAll = true
    /// 自定义背景图片文件路径（空串表示未上传图片）
    @Published var backgroundImagePath: String = ""

    private let customAccentKey = "beans.accent.custom"
    private let backgroundKey = "beans.background.custom"
    private let syncAllKey = "beans.background.syncAll"
    private let backgroundImageKey = "beans.background.image"

    private init() {
        accent = BeansAccent(rawValue: UserDefaults.standard.string(forKey: AccentTheme.key) ?? "") ?? .amber
        let savedAccent = UserDefaults.standard.string(forKey: customAccentKey)
        customAccentHex = (savedAccent?.isEmpty ?? true) ? nil : savedAccent
        backgroundHex = UserDefaults.standard.string(forKey: backgroundKey) ?? ""
        backgroundSyncAll = UserDefaults.standard.object(forKey: syncAllKey) as? Bool ?? true
        backgroundImagePath = UserDefaults.standard.string(forKey: backgroundImageKey) ?? ""
    }

    func set(_ newAccent: BeansAccent) {
        guard accent != newAccent else { return }
        accent = newAccent
        UserDefaults.standard.set(newAccent.rawValue, forKey: AccentTheme.key)
    }

    /// 自定义强调色（色盘选色）
    func setCustomAccent(_ hex: String?) {
        let normalized = hex?.isEmpty == true ? nil : hex
        customAccentHex = normalized
        UserDefaults.standard.set(normalized ?? "", forKey: customAccentKey)
    }

    func clearCustomAccent() {
        setCustomAccent(nil)
    }

    /// 自定义背景色
    func setBackground(_ hex: String) {
        backgroundHex = hex
        UserDefaults.standard.set(hex, forKey: backgroundKey)
    }

    func setBackgroundSyncAll(_ on: Bool) {
        backgroundSyncAll = on
        UserDefaults.standard.set(on, forKey: syncAllKey)
    }

    /// 自定义强调色 Color
    var customAccent: Color? {
        guard let customAccentHex else { return nil }
        return Color(hex: customAccentHex)
    }

    /// 自定义背景色 Color
    var customBackground: Color? {
        guard !backgroundHex.isEmpty else { return nil }
        return Color(hex: backgroundHex)
    }

    /// 上传的背景图片（按路径加载）
    var customBackgroundImage: UIImage? {
        guard !backgroundImagePath.isEmpty else { return nil }
        return UIImage(contentsOfFile: backgroundImagePath)
    }

    /// 保存用户上传的背景图片（写入 Documents，路径持久化）
    func setBackgroundImage(_ data: Data) {
        let url = Self.backgroundImageURL()
        do {
            try data.write(to: url, options: .atomic)
            backgroundImagePath = url.path
            UserDefaults.standard.set(url.path, forKey: backgroundImageKey)
        } catch {
            backgroundImagePath = ""
            UserDefaults.standard.set("", forKey: backgroundImageKey)
        }
    }

    func clearBackgroundImage() {
        if !backgroundImagePath.isEmpty {
            try? FileManager.default.removeItem(atPath: backgroundImagePath)
        }
        backgroundImagePath = ""
        UserDefaults.standard.set("", forKey: backgroundImageKey)
    }

    private static func backgroundImageURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("beans-background.jpg")
    }
}

/// 当前配色读取 / 写入（持久化到 UserDefaults，统一走 ThemeStore）
enum AccentTheme {
    static let key = "beans.accent"

    static var current: BeansAccent {
        ThemeStore.shared.accent
    }

    static func set(_ accent: BeansAccent) {
        ThemeStore.shared.set(accent)
    }
}

// MARK: - 背景氛围渐变（让液态玻璃始终有内容可采样）

extension LinearGradient {
    /// 暖调咖啡色系背景
    static let beansBackdrop = LinearGradient(
        colors: [
            Color(uiColor: .beansBackground),
            Color(uiColor: .beansBackground).opacity(0.72),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 强调色渐变（跟随配色主题）
    static var beansAccent: LinearGradient {
        LinearGradient(
            colors: AccentTheme.current.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 浅色立体阴影（卡片分层质感）

struct BeansCardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat
    var y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark ? .black.opacity(0.35) : .black.opacity(0.08),
            radius: radius,
            y: y
        )
    }
}

extension View {
    /// 卡片阴影：浅色模式柔和阴影提升层次，深色模式轻微阴影保持立体
    func beansCardShadow(radius: CGFloat = 9, y: CGFloat = 3) -> some View {
        modifier(BeansCardShadowModifier(radius: radius, y: y))
    }
}

// MARK: - 主题模式 ↔ 系统外观

extension BeansThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
// MARK: - 颜色工具（hex 解析 / 明暗调整，供色盘自定义使用）

extension UIColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8, let raw = UInt64(value, radix: 16) else { return nil }
        let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
        if value.count == 8 {
            a = CGFloat((raw >> 24) & 0xFF) / 255
            r = CGFloat((raw >> 16) & 0xFF) / 255
            g = CGFloat((raw >> 8) & 0xFF) / 255
            b = CGFloat(raw & 0xFF) / 255
        } else {
            a = 1
            r = CGFloat((raw >> 16) & 0xFF) / 255
            g = CGFloat((raw >> 8) & 0xFF) / 255
            b = CGFloat(raw & 0xFF) / 255
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int(r * 255), Int(g * 255), Int(b * 255)
        )
    }

    func shaded(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = max(0, 1 - amount)
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: a)
    }
}

extension Color {
    init?(hex: String) {
        guard let ui = UIColor(hex: hex) else { return nil }
        self.init(uiColor: ui)
    }

    var hexString: String {
        UIColor(self).hexString
    }
}
