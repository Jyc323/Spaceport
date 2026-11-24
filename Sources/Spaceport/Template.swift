import Cocoa

// MARK: - 数据模型（保存为 JSON，可以手动编辑）

/// 窗口在屏幕可用区域中的相对位置（0~1），换屏幕/分辨率也能用
struct RelRect: Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    init(absolute r: CGRect, in area: CGRect) {
        func norm(_ v: CGFloat) -> Double {
            (min(max(Double(v), 0), 1) * 10000).rounded() / 10000
        }
        x = norm((r.minX - area.minX) / area.width)
        y = norm((r.minY - area.minY) / area.height)
        w = norm(r.width / area.width)
        h = norm(r.height / area.height)
    }

    func absolute(in area: CGRect) -> CGRect {
        CGRect(x: area.minX + CGFloat(x) * area.width,
               y: area.minY + CGFloat(y) * area.height,
               width: CGFloat(w) * area.width,
               height: CGFloat(h) * area.height).integral
    }
}

struct WindowEntry: Codable {
    var bundleID: String
    var appName: String
    var frame: RelRect
    /// 浏览器：这个窗口的标签页网址
    var urls: [String]?
    /// 浏览器：当前选中的是第几个标签页（从 1 开始）
    var activeTab: Int?
    /// Terminal：工作目录
    var directory: String?
}

struct Template: Codable {
    var name: String
    /// 从最后面到最前面的顺序（恢复时按这个顺序打开，最后一个在最上层）
    var windows: [WindowEntry]
}

private struct StoreFile: Codable {
    var newSpaceTemplate: String?
    var templates: [Template]
    /// 桌面名字：桌面标识 → 名字
    var spaceNames: [String: String]?
}

// MARK: - 存储

final class TemplateStore {
    static let shared = TemplateStore()

    let folderURL: URL
    let fileURL: URL
    private var file: StoreFile

    var templates: [Template] { file.templates }
    var newSpaceTemplateName: String? { file.newSpaceTemplate }
    var newSpaceTemplate: Template? {
        guard let name = file.newSpaceTemplate else { return nil }
        return template(named: name)
    }

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folderURL = support.appendingPathComponent("Spaceport", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("templates.json")
        file = StoreFile(newSpaceTemplate: Config.builtInTemplateName,
                         templates: [TemplateStore.builtInTemplate()])
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            reload()
        } else {
            save()
        }
    }

    /// 重新读取文件（你手动改了 templates.json 之后，打开菜单时会自动读到）
    func reload() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            file = try JSONDecoder().decode(StoreFile.self, from: data)
        } catch {
            log("templates.json 格式有误，已备份并继续使用之前的模板: \(error)")
            let backup = folderURL.appendingPathComponent("templates.broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    func template(named name: String) -> Template? {
        file.templates.first { $0.name == name }
    }

    func upsert(_ template: Template) {
        if let i = file.templates.firstIndex(where: { $0.name == template.name }) {
            file.templates[i] = template
        } else {
            file.templates.append(template)
        }
        save()
    }

    func delete(named name: String) {
        file.templates.removeAll { $0.name == name }
        if file.newSpaceTemplate == name { file.newSpaceTemplate = nil }
        save()
    }

    func setNewSpaceTemplate(_ name: String?) {
        file.newSpaceTemplate = name
        save()
    }

    func spaceName(forKey key: String) -> String? {
        file.spaceNames?[key]
    }

    func setSpaceName(_ name: String?, forKey key: String) {
        var names = file.spaceNames ?? [:]
        names[key] = name
        file.spaceNames = names.isEmpty ? nil : names
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        do {
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            log("保存模板失败: \(error)")
        }
    }

    /// 内置模板：Edge 左 60%，Terminal 右 40%
    static func builtInTemplate() -> Template {
        Template(name: Config.builtInTemplateName, windows: [
            WindowEntry(bundleID: "com.microsoft.edgemac", appName: "Microsoft Edge",
                        frame: RelRect(x: 0.005, y: 0.01, w: 0.59, h: 0.98)),
            WindowEntry(bundleID: Config.terminalBundleID, appName: "Terminal",
                        frame: RelRect(x: 0.605, y: 0.01, w: 0.39, h: 0.98)),
        ])
    }
}
