import Cocoa

/// 把当前桌面拍成一个模板
enum Capture {
    /// 只保存"当前显示器"（鼠标所在的显示器，也就是你点菜单栏的那块屏幕）上的窗口
    static func currentSpace() -> (screen: NSScreen, windows: [WindowEntry])? {
        guard let screen = Geometry.screenUnderMouse() else { return nil }
        let area = Geometry.usableArea(of: screen)
        let windows = WindowList.onCurrentSpace(on: screen)
        guard !windows.isEmpty else { return (screen, []) }

        // 浏览器和 Terminal 的额外信息，通过 AppleScript 一次性取回，再按窗口位置对上号
        var browserPools: [String: [BrowserWindow]] = [:]
        for id in Set(windows.map(\.bundleID)) where Config.chromiumBrowsers.contains(id) {
            browserPools[id] = browserWindows(bundleID: id)
        }
        var terminalPool = windows.contains { $0.bundleID == Config.terminalBundleID }
            ? terminalWindows() : []

        var entries: [WindowEntry] = []
        // 屏幕列表是从前到后，模板里存从后到前
        for w in windows.reversed() {
            var entry = WindowEntry(bundleID: w.bundleID, appName: w.appName,
                                    frame: RelRect(absolute: w.bounds, in: area))

            if Config.chromiumBrowsers.contains(w.bundleID),
               let match = takeClosest(to: w.bounds, from: &browserPools[w.bundleID, default: []]) {
                entry.urls = match.urls
                entry.activeTab = match.activeTab
            }
            if w.bundleID == Config.terminalBundleID,
               let match = takeClosest(to: w.bounds, from: &terminalPool) {
                entry.directory = match.directory
            }
            entries.append(entry)
        }
        return (screen, entries)
    }

    // MARK: 浏览器

    struct BrowserWindow: HasBounds {
        let bounds: CGRect
        let activeTab: Int
        let urls: [String]
    }

    private static func browserWindows(bundleID: String) -> [BrowserWindow] {
        // 注意：浏览器词典里有 "tab" 这个类，所以分隔符用 character id 9 而不是 tab
        let script = """
        set sep to character id 9
        set nl to character id 10
        set out to ""
        tell application id "\(bundleID)"
            repeat with w in windows
                set b to bounds of w
                set ln to ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text)
                set ln to ln & sep & ((active tab index of w) as text)
                repeat with t in tabs of w
                    set ln to ln & sep & (URL of t)
                end repeat
                set out to out & ln & nl
            end repeat
        end tell
        return out
        """
        guard let output = runAppleScript(script) else { return [] }
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, let bounds = parseBounds(parts[0]) else { return nil }
            return BrowserWindow(bounds: bounds, activeTab: Int(parts[1]) ?? 1,
                                 urls: Array(parts.dropFirst(2)).filter { !$0.isEmpty })
        }
    }

    // MARK: Terminal

    struct TerminalWindow: HasBounds {
        let bounds: CGRect
        let directory: String?
    }

    private static func terminalWindows() -> [TerminalWindow] {
        let script = """
        set sep to character id 9
        set nl to character id 10
        set out to ""
        tell application id "\(Config.terminalBundleID)"
            repeat with w in windows
                set b to bounds of w
                set ln to ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text)
                set ln to ln & sep & (tty of selected tab of w)
                set out to out & ln & nl
            end repeat
        end tell
        return out
        """
        guard let output = runAppleScript(script) else { return [] }
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count >= 2, let bounds = parseBounds(parts[0]) else { return nil }
            return TerminalWindow(bounds: bounds, directory: workingDirectory(ofTTY: parts[1]))
        }
    }

    /// 找到这个终端标签页里 shell 的当前目录
    private static func workingDirectory(ofTTY tty: String) -> String? {
        let name = tty.replacingOccurrences(of: "/dev/", with: "")
        let shells: Set<String> = ["zsh", "bash", "fish", "sh", "tcsh", "csh", "ksh", "dash", "nu"]
        let processes = runProcess("/bin/ps", ["-t", name, "-o", "pid=,comm="])
            .split(separator: "\n")
            .compactMap { line -> (String, String)? in
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let comm = (String(parts[1]) as NSString).lastPathComponent
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                return (String(parts[0]), comm)
            }
        // 用最里层的 shell（最后一个）
        guard let pid = processes.last(where: { shells.contains($0.1) })?.0 else { return nil }
        let output = runProcess("/usr/sbin/lsof", ["-a", "-p", pid, "-d", "cwd", "-Fn"])
        return output.split(separator: "\n").first { $0.hasPrefix("n") }.map { String($0.dropFirst()) }
    }

    // MARK: 工具

    private static func parseBounds(_ s: String) -> CGRect? {
        let n = s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard n.count == 4 else { return nil }
        return CGRect(x: n[0], y: n[1], width: n[2] - n[0], height: n[3] - n[1])
    }

    /// 从候选里取出和目标位置最接近的一个（并移出候选）
    private static func takeClosest<T: HasBounds>(to target: CGRect, from pool: inout [T]) -> T? {
        guard let best = pool.indices.min(by: {
            Geometry.distance(pool[$0].bounds, target) < Geometry.distance(pool[$1].bounds, target)
        }), Geometry.distance(pool[best].bounds, target) < 80 else { return nil }
        return pool.remove(at: best)
    }
}

protocol HasBounds {
    var bounds: CGRect { get }
}
