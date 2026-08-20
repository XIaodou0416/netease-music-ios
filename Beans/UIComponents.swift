import SwiftUI

// ============================================================================
// 统一 UI 组件层（UIComponents.swift）
// 全项目复用：保证布局一致、尺寸自适应、渲染稳定。
// 关键决策：液态玻璃(.glassEffect)只用于"静态容器"（底栏、播放器面板、
// 登录卡片、大卡片）；滚动列表行/动态内容一律使用普通圆角背景，
// 避免 iOS 26 玻璃在滚动内容中采样异常导致的重叠、糊块、空白等渲染 bug。
// ============================================================================

// MARK: - 玻璃卡片容器（ViewModifier，可直接 .beansGlassCard() 使用）

struct BeansGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.beansGlassFill)          // 玻璃需要非透明基底，否则渲染糊块/失效
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - 封面图（统一占位，避免空白占位框）

struct BeansCover: View {
    let url: URL?
    var cornerRadius: CGFloat = 16

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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - 空状态（列表/数据为空时的兜底，禁止空白页）

struct BeansEmptyState: View {
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

// MARK: - 错误重试（网络失败兜底，禁止卡死/白屏）

struct BeansErrorState: View {
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
                Label("重新加载", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.beansLabel)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.beansGlassFill)
                    .glassEffect(.regular)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - 页面背景与 List 统一样式

struct BeansPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.beansBackground.ignoresSafeArea())
    }
}

struct BeansListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

extension View {
    /// 统一页面背景（仅对根视图使用，避免多重背景导致色块错乱）
    func beansPageBackground() -> some View {
        modifier(BeansPageBackground())
    }

    /// 统一 List 样式：无分隔线、透明行背景、统一边距
    func beansListStyle() -> some View {
        modifier(BeansListStyle())
    }

    /// 玻璃卡片容器（静态大卡片使用；滚动列表行不要用）
    func beansGlassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(BeansGlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// 统一普通卡片行（列表行不用玻璃，保证渲染稳定）
    func beansRowCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.beansCard.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
            )
    }
}