import Cocoa

// MARK: - 配置（修改后重新运行 ./install.sh 即可生效）

enum Config {
    /// 切换桌面后等多久再动手（等切换动画结束）
    static let settleDelay: TimeInterval = 0.6
    /// 只有新桌面上没有任何普通窗口时才自动套用模板
    /// （如果你有"分配给所有桌面"的 App，把它改成 false）
    static let requireEmptySpace = true

    /// 这些浏览器会额外保存/恢复标签页网址（它们的 AppleScript 接口相同）
    static let chromiumBrowsers: Set<String> = [
        "com.microsoft.edgemac",
        "com.google.Chrome",
        "com.brave.Browser",
        "org.chromium.Chromium",
    ]
    /// Terminal 会额外保存/恢复工作目录
    static let terminalBundleID = "com.apple.Terminal"

    static let builtInTemplateName = "Edge + Terminal"

    /// 版本号来自 Info.plist（由 scripts/build.sh 从 VERSION 文件写入）
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
    static let homepage = "https://github.com/Jyc323/Spaceport"
}

// MARK: - 界面语言

/// 系统首选语言是中文时显示中文，否则显示英文
func L(_ zh: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

// MARK: - 日志

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write("[\(stamp)] \(message)\n".data(using: .utf8)!)
}

// MARK: - 等待

/// 让主线程处理一会儿事件（比 sleep 好：系统的 App 列表等信息会继续更新）
func pump(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

/// 反复检查条件，直到成立或超时
@discardableResult
func waitUntil(timeout: TimeInterval, interval: TimeInterval = 0.1, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        pump(interval)
    }
    return condition()
}

// MARK: - 外部命令 / AppleScript

func runProcess(_ path: String, _ args: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

/// 执行 AppleScript，成功返回结果文本，失败返回 nil
@discardableResult
func runAppleScript(_ source: String) -> String? {
    var error: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error {
        log("AppleScript 出错: \(error)")
        if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
            log("没有自动化权限：系统设置 → 隐私与安全性 → 自动化 → Spaceport，勾选对应 App")
        }
        return nil
    }
    return result?.stringValue ?? ""
}

/// 转成 AppleScript 字符串字面量
func appleScriptString(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

/// 转成安全的 shell 单引号字符串
func shellQuote(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// MARK: - 屏幕坐标
//
// NSScreen 用"左下角原点"，而 AX / AppleScript / CGWindowList 都用"主屏左上角原点"。
// 下面所有矩形都统一成左上角原点。

enum Geometry {
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// 屏幕可用区域（去掉菜单栏和 Dock），左上角原点
    static func usableArea(of screen: NSScreen) -> CGRect {
        let vf = screen.visibleFrame
        return CGRect(x: vf.minX, y: primaryHeight - vf.maxY, width: vf.width, height: vf.height)
    }

    static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    static func screen(containing topLeftPoint: CGPoint) -> NSScreen? {
        let p = CGPoint(x: topLeftPoint.x, y: primaryHeight - topLeftPoint.y)
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    /// AppleScript 的 bounds：{左, 上, 右, 下}
    static func appleScriptBounds(_ r: CGRect) -> String {
        "{\(Int(r.minX)), \(Int(r.minY)), \(Int(r.maxX)), \(Int(r.maxY))}"
    }

    /// 两个矩形差多少（用于把 AppleScript 窗口和屏幕上的窗口对应起来）
    static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.maxX - b.maxX) + abs(a.maxY - b.maxY)
    }
}
