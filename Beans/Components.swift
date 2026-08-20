import SwiftUI

// ============================================================================
// Beans 全新 UI 基础组件（Components.swift）
// 全部页面复用；布局全部自适应，不写死宽度；空态/错误态全覆盖。
// ============================================================================

// MARK: - 封面（统一占位图标，杜绝空白占位框）

struct BeansCover: View {
    let url: URL?
    var radius: CGFloat = 16

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Rectangle().fill(Color.beansCard)
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(Color.beansSecondary.opacity(0.55))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - 空状态（数据为空兜底）

struct BeansEmpty: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Color.beansSecondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.beansLabel)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.beansSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - 错误重试（网络失败兜底）

struct BeansError: View {
    let title: String
    var subtitle: String = "请检查网络后重试"
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.beansSecondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.beansLabel)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.beansSecondary)
            Button(action: retry) {
                Text("重新加载")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.beansCard, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - 通用卡片行（列表行专用，保证渲染稳定）

struct BeansRowCard: ViewModifier {
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(Color.beansCard.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

// MARK: - 玻璃卡片（仅用于静态大块容器）

struct BeansGlassCard: ViewModifier {
    var radius: CGFloat = 22
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.beansGlassFill)
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - 修饰器入口

extension View {
    /// 统一页面背景
    func beansPage() -> some View {
        self.background(Color.beansBackground.ignoresSafeArea())
    }

    /// 统一 List 样式
    func beansList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    /// 列表行卡片
    func beansRow(radius: CGFloat = 14) -> some View {
        modifier(BeansRowCard(radius: radius))
    }

    /// 玻璃大卡片
    func beansGlass(radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(BeansGlassCard(radius: radius, padding: padding))
    }
}