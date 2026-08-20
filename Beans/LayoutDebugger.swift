import SwiftUI
import UIKit

// MARK: - UI 布局检测工具（调试专用，默认关闭）
// 开关关闭时：log / reportFrame / snapshot 等所有检测入口第一行即返回，不执行任何检测、
// 不启动定时器、不采样视图树，对播放器、歌词及全部页面零额外影响。
// 开关开启时：仅在布局事件 / 切歌 / 视图出现时输出控制台日志，不弹窗不打断用户。

enum LayoutDebugger {
    /// UserDefaults 持久化键（与「我的 → 外观」页开关共用）
    static let key = "beans.layoutDebugger.enabled"

    /// 当前开关状态（默认 false；每次读取 UserDefaults，保证运行时切换即时生效）
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - 通用日志（唯一输出入口；关闭时立即返回，零开销）

    static func log(_ message: String, file: String = #fileID, line: Int = #line) {
        guard isEnabled else { return }
        let fileTag = file.components(separatedBy: "/").last ?? file
        print("[LayoutDebug] \(fileTag):\(line) \(message)")
    }

    static func logViewEvent(_ viewName: String, _ event: String, file: String = #fileID, line: Int = #line) {
        log("📐 [视图] \(viewName) → \(event)", file: file, line: line)
    }

    static func logPlayerEvent(_ message: String, file: String = #fileID, line: Int = #line) {
        log("🎵 [播放器] \(message)", file: file, line: line)
    }

    // MARK: - 开关状态变化（始终打印一次，便于确认开启/停止）

    static func onStateChanged(enabled: Bool) {
        if enabled {
            print("[LayoutDebug] 🛠 UI布局检测工具已开启（默认关闭，仅输出控制台日志）")
            snapshotKeyWindow(tag: "开启检测-当前窗口")
        } else {
            print("[LayoutDebug] ⛔ UI布局检测工具已关闭，所有检测代码停止执行")
        }
    }

    // MARK: - 视图布局风险提示（frame / safeArea / 空布局）

    static func reportFrame(_ viewName: String, size: CGSize, safeArea: EdgeInsets) {
        guard isEnabled else { return }
        log("📏 [布局] \(viewName) size=\(Int(size.width))x\(Int(size.height)) safeArea=top\(Int(safeArea.top)) bottom\(Int(safeArea.bottom))")
        if size.width <= 0 || size.height <= 0 {
            log("⚠️ [布局风险] \(viewName) 尺寸为 0：子视图可能未正确 addSubview，或缺少约束")
        }
        if safeArea.top == 0 && safeArea.bottom == 0 {
            log("⚠️ [布局风险] \(viewName) 未感知安全区（safeArea 为 0），全屏页面建议适配灵动岛/Home 条")
        }
    }

    // MARK: - 硬编码颜色提示（非动态系统色 → 疑似硬编码）

    static func reportHardcodedColor(_ viewName: String, color: UIColor?) {
        guard isEnabled else { return }
        guard let color else { return }
        let desc = color.cgColor.description
        let isDynamic = desc.contains("UIDynamic")
        if !isDynamic {
            log("🎨 [硬编码颜色提示] \(viewName) backgroundColor=\(color)（静态色，建议改用 Color.beans* 动态主题色）")
        }
    }

    // MARK: - 切歌布局监控（配合播放器 onChange 调用）

    static func logSongSwitch(songID: Int?) {
        guard isEnabled else { return }
        logPlayerEvent("切歌 → id=\(songID ?? -1)，开始输出播放器布局快照（排查“切歌瞬间正常随后错乱”）")
        snapshotKeyWindow(tag: "切歌后-播放器布局")
    }

    // MARK: - 视图树快照（约束 / 尺寸 / safeArea / 子视图 / 颜色一站式体检）

    static func snapshotKeyWindow(tag: String) {
        guard isEnabled else { return }
        guard let window = keyWindow() else {
            log("⚠️ [快照] \(tag) 未找到当前 keyWindow")
            return
        }
        log("🔍 [快照] \(tag)：开始遍历视图树（根子视图 \(window.subviews.count) 个）")
        var depth = 0
        walk(window, depth: &depth, maxDepth: 14)
    }

    private static func keyWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                  windowScene.activationState == .foregroundActive else { continue }
            if let key = windowScene.keyWindow { return key }
            return windowScene.windows.first
        }
        return nil
    }

    private static func walk(_ view: UIView, depth: inout Int, maxDepth: Int) {
        guard depth < maxDepth else { return }
        let indent = String(repeating: "  ", count: depth)
        let name = String(describing: type(of: view))
        let f = view.frame
        let b = view.bounds
        let frameDesc = "x=\(Int(f.origin.x)) y=\(Int(f.origin.y)) \(Int(f.width))x\(Int(f.height))"

        log("\(indent)└ \(name) frame[\(frameDesc)] bounds=\(Int(b.width))x\(Int(b.height)) subviews=\(view.subviews.count)")

        // ① 约束缺失 / 歧义约束
        if view.hasAmbiguousLayout {
            log("\(indent)   ⚠️ [约束缺失/歧义] \(name) hasAmbiguousLayout = true")
        }
        // ② 尺寸为 0 / 子视图未 addSubview
        if b.width <= 0 || b.height <= 0 {
            log("\(indent)   ⚠️ [布局风险] \(name) bounds 为 0：可能未 addSubview 或缺少约束")
        }
        // ③ safeArea 未适配
        let safe = view.safeAreaInsets
        if safe.top == 0 && safe.bottom == 0 {
            log("\(indent)   ⚠️ [safeArea 提示] \(name) safeAreaInsets 为 0")
        }
        // ④ 硬编码颜色
        reportHardcodedColor("\(indent)\(name)", color: view.backgroundColor)

        depth += 1
        for subview in view.subviews {
            walk(subview, depth: &depth, maxDepth: maxDepth)
        }
        depth -= 1
    }
}

// MARK: - SwiftUI 接入点：给关键视图挂上检测探针（关闭时仅保留空壳，几乎零开销）

struct LayoutDebugModifier: ViewModifier {
    let viewName: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        LayoutDebugger.logViewEvent(viewName, "出现")
                        LayoutDebugger.reportFrame(viewName, size: geo.size, safeArea: geo.safeAreaInsets)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        LayoutDebugger.logViewEvent(viewName, "布局尺寸变化")
                        LayoutDebugger.reportFrame(viewName, size: newSize, safeArea: geo.safeAreaInsets)
                    }
            }
        )
    }
}

extension View {
    /// 挂载布局检测探针（仅 LayoutDebugger.isEnabled 为 true 时输出日志）
    func layoutDebug(_ viewName: String) -> some View {
        modifier(LayoutDebugModifier(viewName: viewName))
    }
}