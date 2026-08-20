import SwiftUI

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
    static let beansAmber = beansDynamic(
        light: UIColor(red: 0.753, green: 0.478, blue: 0.039, alpha: 1),  // #C07A0A
        dark: UIColor(red: 0.949, green: 0.639, blue: 0.235, alpha: 1)    // #F2A33C
    )
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
    static let beansAmber = Color(uiColor: .beansAmber)
    static let beansSage = Color(uiColor: .beansSage)
    static let beansGlassFill = Color(uiColor: .beansGlassFill)
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

    /// 强调色渐变（琥珀暖金）
    static let beansAccent = LinearGradient(
        colors: [Color.beansAmber, Color(uiColor: .beansAmber).opacity(0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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