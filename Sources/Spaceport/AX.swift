import Cocoa
import ApplicationServices

/// 辅助功能（Accessibility）API：用来摆放任意 App 的窗口、点"新建窗口"菜单
enum AX {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) ?? []
    }

    /// App 的普通窗口（不含最小化的）
    static func windows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        let all: [AXUIElement] = attribute(app, kAXWindowsAttribute) ?? []
        return all.filter { w in
            let role: String? = attribute(w, kAXRoleAttribute)
            let minimized: Bool = attribute(w, kAXMinimizedAttribute) ?? false
            return role == (kAXWindowRole as String) && !minimized
        }
    }

    static func setFrame(_ window: AXUIElement, _ rect: CGRect) {
        var origin = rect.origin
        var size = rect.size
        guard let pos = AXValueCreate(.cgPoint, &origin), let sz = AXValueCreate(.cgSize, &size) else { return }
        // 先挪再改大小再挪一次：避免窗口被屏幕边缘挡住导致尺寸不对
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
    }

    static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    /// 在 App 的菜单里找到快捷键是 ⌘N 的项（新建窗口/新建文稿）并点击。
    /// 不需要把 App 切到前台，所以不会跳到别的桌面。
    @discardableResult
    static func pressNewWindowMenuItem(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar: AXUIElement = attribute(app, kAXMenuBarAttribute) else { return false }
        for barItem in children(menuBar).dropFirst() { // 跳过  菜单
            for menu in children(barItem) {
                for item in children(menu) {
                    let key: String? = attribute(item, kAXMenuItemCmdCharAttribute)
                    let modifiers: Int? = attribute(item, kAXMenuItemCmdModifiersAttribute)
                    let enabled: Bool = attribute(item, kAXEnabledAttribute) ?? false
                    // modifiers == 0 表示只按 ⌘
                    if key?.uppercased() == "N", modifiers == 0, enabled {
                        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                    }
                }
            }
        }
        return false
    }
}
