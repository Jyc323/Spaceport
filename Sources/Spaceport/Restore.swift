import Cocoa

/// 在当前桌面上套用一个模板
enum Restore {
    private(set) static var isBusy = false

    /// screen 为 nil 时套用到鼠标所在的显示器
    static func apply(_ template: Template, on targetScreen: NSScreen? = nil) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        guard let screen = targetScreen ?? Geometry.screenUnderMouse() else { return }
        let area = Geometry.usableArea(of: screen)
        log("套用模板「\(template.name)」，共 \(template.windows.count) 个窗口")

        // 普通 App 需要辅助功能权限；浏览器和 Terminal 用 AppleScript，不需要
        let needsAX = template.windows.contains { !isScriptable($0.bundleID) }
        let axOK = !needsAX || AX.isTrusted(prompt: true)
        if !axOK {
            log("没有辅助功能权限，跳过普通 App：系统设置 → 隐私与安全性 → 辅助功能 → 打开 Spaceport")
        }

        for entry in template.windows {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleID) != nil else {
                log("没有安装 \(entry.appName)，跳过")
                continue
            }
            let rect = entry.frame.absolute(in: area)
            if Config.chromiumBrowsers.contains(entry.bundleID) {
                openBrowserWindow(entry, rect)
            } else if entry.bundleID == Config.terminalBundleID {
                openTerminalWindow(entry, rect)
            } else if axOK {
                openAppWindow(entry, rect)
            }
        }

        // 模板里最后一个窗口在最上层，把它的 App 切到前台
        if let last = template.windows.last,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: last.bundleID).first {
            app.activate(options: [])
        }
        log("模板「\(template.name)」套用完成")
    }

    private static func isScriptable(_ bundleID: String) -> Bool {
        Config.chromiumBrowsers.contains(bundleID) || bundleID == Config.terminalBundleID
    }

    // MARK: 浏览器：新窗口 + 标签页

    private static func openBrowserWindow(_ entry: WindowEntry, _ rect: CGRect) {
        let urls = entry.urls ?? []
        var tabs = ""
        if let first = urls.first {
            tabs += "set URL of active tab of w to \(appleScriptString(first))\n"
            for url in urls.dropFirst() {
                tabs += "make new tab at end of tabs of w with properties {URL:\(appleScriptString(url))}\n"
            }
            if let active = entry.activeTab, active >= 1, active <= urls.count {
                tabs += "set active tab index of w to \(active)\n"
            }
        }
        let id = entry.bundleID
        runAppleScript("""
        set wasRunning to application id "\(id)" is running
        tell application id "\(id)"
            if wasRunning then
                set w to make new window
            else
                activate
                repeat 80 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.1
                end repeat
                set w to window 1
            end if
            delay 0.3
            \(tabs)
            set bounds of w to \(Geometry.appleScriptBounds(rect))
        end tell
        """)
    }

    // MARK: Terminal：新窗口 + 工作目录

    private static func openTerminalWindow(_ entry: WindowEntry, _ rect: CGRect) {
        let command = entry.directory.map { "cd \(shellQuote($0)) && clear" }
        let firstWindowCommand = command.map { "do script \(appleScriptString($0)) in window 1" } ?? ""
        runAppleScript("""
        set wasRunning to application id "\(Config.terminalBundleID)" is running
        tell application id "\(Config.terminalBundleID)"
            if wasRunning then
                do script \(appleScriptString(command ?? ""))
            else
                activate
                repeat 80 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.1
                end repeat
                \(firstWindowCommand)
            end if
            delay 0.2
            set bounds of window 1 to \(Geometry.appleScriptBounds(rect))
        end tell
        """)
    }

    // MARK: 其他 App：通过辅助功能 API

    private static func openAppWindow(_ entry: WindowEntry, _ rect: CGRect) {
        var window: AXUIElement?

        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).first {
            // 已经在运行：点它的 ⌘N 菜单，等新窗口出现
            window = newWindow(pid: app.processIdentifier) {
                AX.pressNewWindowMenuItem(pid: app.processIdentifier)
            }
        } else {
            // 没运行：启动它，通常会在当前桌面打开第一个窗口
            _ = runProcess("/usr/bin/open", ["-b", entry.bundleID])
            var pid: pid_t = 0
            waitUntil(timeout: 10) {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleID).first {
                    pid = app.processIdentifier
                    return true
                }
                return false
            }
            guard pid != 0 else {
                log("\(entry.appName) 启动超时，跳过")
                return
            }
            waitUntil(timeout: 6) { !AX.windows(pid: pid).isEmpty }
            let app = AXUIElementCreateApplication(pid)
            window = AX.attribute(app, kAXMainWindowAttribute) ?? AX.windows(pid: pid).first
            if window == nil {
                window = newWindow(pid: pid) { AX.pressNewWindowMenuItem(pid: pid) }
            }
        }

        guard let window else {
            log("\(entry.appName) 没有打开新窗口（可能不支持 ⌘N），跳过")
            return
        }
        AX.setFrame(window, rect)
        AX.raise(window)
    }

    /// 执行 action，然后等一个之前没有的窗口出现
    private static func newWindow(pid: pid_t, action: () -> Bool) -> AXUIElement? {
        let before = AX.windows(pid: pid)
        guard action() else { return nil }
        var found: AXUIElement?
        waitUntil(timeout: 4) {
            found = AX.windows(pid: pid).first { w in !before.contains { CFEqual($0, w) } }
            return found != nil
        }
        return found
    }
}
