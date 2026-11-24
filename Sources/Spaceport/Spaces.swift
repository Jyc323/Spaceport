import Cocoa

// MARK: - macOS 私有 Spaces API（yabai / Hammerspoon 等工具也用这些）

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray

enum Spaces {
    static let connection = CGSMainConnectionID()

    /// 当前激活的桌面 ID
    static func active() -> UInt64 {
        CGSGetActiveSpace(connection)
    }

    private static func displays() -> [[String: Any]] {
        (CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]]) ?? []
    }

    private static func spaceID(_ space: [String: Any]) -> UInt64? {
        ((space["ManagedSpaceID"] as? NSNumber) ?? (space["id64"] as? NSNumber))?.uint64Value
    }

    /// 所有显示器上的普通桌面（type 0；不含全屏 App 的桌面）
    static func userSpaces() -> Set<UInt64> {
        var ids = Set<UInt64>()
        for display in displays() {
            for space in (display["Spaces"] as? [[String: Any]]) ?? [] {
                guard (space["type"] as? NSNumber)?.intValue == 0 else { continue }
                if let n = (space["ManagedSpaceID"] as? NSNumber) ?? (space["id64"] as? NSNumber) {
                    ids.insert(n.uint64Value)
                }
            }
        }
        return ids
    }

    /// 每个显示器当前显示的桌面（只含普通桌面）
    /// screen 为 nil 表示所有显示器共用桌面（没开「显示器具有单独的空间」）
    static func currentSpacePerDisplay() -> [(spaceID: UInt64, screen: NSScreen?)] {
        var result: [(spaceID: UInt64, screen: NSScreen?)] = []
        for display in displays() {
            guard let current = display["Current Space"] as? [String: Any],
                  (current["type"] as? NSNumber)?.intValue == 0,
                  let n = (current["ManagedSpaceID"] as? NSNumber) ?? (current["id64"] as? NSNumber)
            else { continue }
            let identifier = display["Display Identifier"] as? String ?? ""
            result.append((n.uint64Value, screen(forDisplayIdentifier: identifier)))
        }
        return result
    }

    /// 某块显示器上当前的桌面；screen 为 nil 时返回当前激活的桌面
    static func currentSpace(on screen: NSScreen?) -> UInt64? {
        let perDisplay = currentSpacePerDisplay()
        if let screen, let match = perDisplay.first(where: { $0.screen?.frame == screen.frame }) {
            return match.spaceID
        }
        if perDisplay.count == 1 { return perDisplay[0].spaceID } // 所有显示器共用桌面
        let active = active()
        return perDisplay.first { $0.spaceID == active }?.spaceID
    }

    /// 用来记桌面名字的标识：优先用系统给桌面的 uuid（通常重启后不变），没有时退回数字 ID
    static func persistentKey(for spaceID: UInt64) -> String {
        for display in displays() {
            for space in (display["Spaces"] as? [[String: Any]]) ?? [] where Self.spaceID(space) == spaceID {
                if let uuid = space["uuid"] as? String, !uuid.isEmpty { return uuid }
            }
        }
        return "id:\(spaceID)"
    }

    private static func screen(forDisplayIdentifier identifier: String) -> NSScreen? {
        guard identifier != "Main" else { return nil }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
            else { continue }
            let uuidString = CFUUIDCreateString(nil, uuid) as String
            if uuidString.caseInsensitiveCompare(identifier) == .orderedSame { return screen }
        }
        return nil
    }
}

// MARK: - 当前桌面上的窗口

struct ScreenWindow {
    let pid: pid_t
    let bundleID: String
    let appName: String
    /// 左上角原点
    let bounds: CGRect
}

enum WindowList {
    private static let ignoredOwners: Set<String> = [
        "Window Server", "Dock", "SystemUIServer", "Control Center",
        "Notification Center", "WindowManager", "Spaceport",
    ]

    /// 当前桌面上看得见的普通 App 窗口，从最前到最后
    static func onCurrentSpace() -> [ScreenWindow] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        var result: [ScreenWindow] = []
        for w in info {
            let layer = (w[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let alpha = (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            let pid = (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            guard layer == 0, alpha > 0.01, pid != myPID, !ignoredOwners.contains(owner),
                  let boundsDict = w[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 80, bounds.height > 80,
                  let app = NSRunningApplication(processIdentifier: pid),
                  let bundleID = app.bundleIdentifier
            else { continue }
            result.append(ScreenWindow(pid: pid, bundleID: bundleID,
                                       appName: app.localizedName ?? owner, bounds: bounds))
        }
        return result
    }

    /// 当前桌面上、位于指定显示器上的窗口（按窗口中心点判断）
    static func onCurrentSpace(on screen: NSScreen) -> [ScreenWindow] {
        onCurrentSpace().filter { w in
            let center = CGPoint(x: w.bounds.midX, y: w.bounds.midY)
            return Geometry.screen(containing: center)?.frame == screen.frame
        }
    }

    static func currentSpaceIsEmpty(on screen: NSScreen?) -> Bool {
        if let screen { return onCurrentSpace(on: screen).isEmpty }
        return onCurrentSpace().isEmpty
    }
}
