// Spaceport — macOS 桌面(Space)布局工具
//
// · 把当前桌面的窗口布局（App、位置、浏览器标签页、终端目录）存成模板
// · 在任意桌面一键套用模板
// · 切换到一个新建的桌面时，自动套用默认模板
// · 给桌面起名字，显示在菜单栏上
//
// 编译: 见 install.sh（需要 Xcode Command Line Tools）

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = TemplateStore.shared
    /// 已经"见过"的桌面。切换到一个没见过的桌面 = 新桌面
    private var seenSpaces = Set<UInt64>()
    private var paused = false
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        seenSpaces = Spaces.userSpaces()
        seenSpaces.insert(Spaces.active())
        log("Spaceport 已启动，当前已有 \(seenSpaces.count) 个桌面，模板文件：\(store.fileURL.path)")

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        // 在两块显示器之间切换焦点时，当前桌面也会变
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        setUpStatusItem()
        updateStatusTitle()
    }

    // MARK: - 新桌面检测

    @objc private func spaceDidChange() {
        updateStatusTitle()
        // 防抖：切换动画期间可能连续触发多次
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkActiveSpace), object: nil)
        perform(#selector(checkActiveSpace), with: nil, afterDelay: Config.settleDelay)
    }

    @objc private func checkActiveSpace() {
        seenSpaces.formIntersection(Spaces.userSpaces()) // 删掉的桌面不再记着

        // 多显示器时每块屏幕各有当前桌面，逐个看有没有没见过的
        let newSpaces = Spaces.currentSpacePerDisplay().filter { !seenSpaces.contains($0.spaceID) }
        newSpaces.forEach { seenSpaces.insert($0.spaceID) }
        guard let target = newSpaces.first, !paused, !Restore.isBusy else { return }

        store.reload()
        guard let template = store.newSpaceTemplate else { return }
        let screen = target.screen ?? Geometry.screenUnderMouse()
        if Config.requireEmptySpace && !WindowList.currentSpaceIsEmpty(on: screen) {
            log("新桌面 \(target.spaceID) 上已经有窗口，跳过")
            return
        }
        log("检测到新桌面 \(target.spaceID)（\(screen?.localizedName ?? "未知显示器")）")
        Restore.apply(template, on: screen)
    }

    // MARK: - 菜单栏

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Spaceport") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "⧉"
        }
        item.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self // 每次打开时重建，模板列表总是最新的
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        store.reload()
        menu.removeAllItems()
        let names = store.templates.map(\.name)

        let currentName = spaceName(on: Geometry.screenUnderMouse())
        let header = NSMenuItem(title: L("当前桌面：\(currentName ?? "未命名")", "Desktop: \(currentName ?? "Untitled")"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(item(L("重命名当前桌面…", "Rename This Desktop…"), #selector(renameCurrentSpace)))
        menu.addItem(.separator())

        menu.addItem(item(L("保存当前桌面为模板…", "Save Desktop as Template…"), #selector(saveCurrentSpace)))

        // 套用
        let applyMenu = NSMenu()
        for name in names {
            applyMenu.addItem(item(name, #selector(applyTemplate(_:)), represented: name))
        }
        menu.addItem(submenu(L("套用到当前桌面", "Apply to This Desktop"), applyMenu, enabled: !names.isEmpty))

        // 新桌面默认模板
        let defaultMenu = NSMenu()
        for name in names {
            let i = item(name, #selector(chooseNewSpaceTemplate(_:)), represented: name)
            i.state = store.newSpaceTemplateName == name ? .on : .off
            defaultMenu.addItem(i)
        }
        defaultMenu.addItem(.separator())
        let none = item(L("不自动套用", "None"), #selector(chooseNewSpaceTemplate(_:)))
        none.state = store.newSpaceTemplate == nil ? .on : .off
        defaultMenu.addItem(none)
        menu.addItem(submenu(L("新桌面自动套用", "Template for New Desktops"), defaultMenu, enabled: true))

        // 删除
        let deleteMenu = NSMenu()
        for name in names {
            deleteMenu.addItem(item(name, #selector(deleteTemplate(_:)), represented: name))
        }
        menu.addItem(submenu(L("删除模板", "Delete Template"), deleteMenu, enabled: !names.isEmpty))

        menu.addItem(.separator())
        menu.addItem(item(paused ? L("恢复自动套用", "Resume Auto-Apply") : L("暂停自动套用", "Pause Auto-Apply"), #selector(togglePause)))
        menu.addItem(item(L("打开模板文件夹", "Open Templates Folder"), #selector(openTemplateFolder)))
        menu.addItem(.separator())
        menu.addItem(item(L("关于 Spaceport \(Config.version)", "About Spaceport \(Config.version)"), #selector(openHomepage)))
        menu.addItem(item(L("退出 Spaceport", "Quit Spaceport"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, represented: String? = nil, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        i.representedObject = represented
        return i
    }

    private func submenu(_ title: String, _ sub: NSMenu, enabled: Bool) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = sub
        i.isEnabled = enabled
        return i
    }

    // MARK: - 桌面名字

    private func spaceKey(on screen: NSScreen?) -> String? {
        Spaces.currentSpace(on: screen).map(Spaces.persistentKey(for:))
    }

    private func spaceName(on screen: NSScreen?) -> String? {
        spaceKey(on: screen).flatMap(store.spaceName(forKey:))
    }

    /// 菜单栏图标旁边显示当前桌面的名字
    @objc private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        let name = spaceName(on: nil)
        if button.image == nil {
            button.title = name.map { "⧉ \($0)" } ?? "⧉"
        } else {
            button.title = name.map { " \($0)" } ?? ""
            button.imagePosition = name == nil ? .imageOnly : .imageLeading
        }
    }

    /// 套用模板时，如果这个桌面还没名字，就用模板名
    private func nameSpaceIfUnnamed(on screen: NSScreen?, as name: String) {
        guard let key = spaceKey(on: screen), store.spaceName(forKey: key) == nil else { return }
        store.setSpaceName(name, forKey: key)
        updateStatusTitle()
    }

    @objc private func renameCurrentSpace() {
        // 鼠标所在的显示器（你点菜单栏的那块）上的当前桌面
        let screen = Geometry.screenUnderMouse()
        guard let key = spaceKey(on: screen) else { return }
        guard let input = askForText(
            title: L("重命名当前桌面", "Rename This Desktop"),
            info: L("名字会显示在菜单栏图标旁边。留空并确定可清除名字。",
                    "The name is shown next to the menu bar icon. Leave empty to clear it."),
            defaultValue: store.spaceName(forKey: key) ?? "",
            placeholder: L("桌面名字", "Desktop name"),
            button: L("确定", "OK"),
            allowEmpty: true
        ) else { return }
        store.setSpaceName(input.isEmpty ? nil : input, forKey: key)
        updateStatusTitle()
        log(input.isEmpty ? "已清除桌面名字" : "桌面已命名为「\(input)」")
    }

    // MARK: - 动作

    @objc private func saveCurrentSpace() {
        // 先拍快照，再弹窗（否则弹窗本身会被拍进去）
        guard let captured = Capture.currentSpace() else { return }
        let (screen, windows) = captured
        guard !windows.isEmpty else {
            showMessage(L("「\(screen.localizedName)」上的当前桌面没有可以保存的窗口",
                          "No windows to save on this desktop of \(screen.localizedName)."))
            return
        }

        let summary = windows.reversed().map { w -> String in
            var line = "• \(w.appName)"
            if let urls = w.urls, !urls.isEmpty { line += L("（\(urls.count) 个标签页）", " (\(urls.count) tabs)") }
            if let dir = w.directory {
                line += " (\((dir as NSString).abbreviatingWithTildeInPath))"
            }
            return line
        }.joined(separator: "\n")

        guard let name = askForName(
            info: L("将保存显示器「\(screen.localizedName)」上的 \(windows.count) 个窗口：\n\(summary)\n\n同名模板会被覆盖。",
                    "Save \(windows.count) windows on \(screen.localizedName):\n\(summary)\n\nA template with the same name will be replaced."),
            defaultName: L("布局 \(store.templates.count + 1)", "Layout \(store.templates.count + 1)")
        ) else { return }

        store.upsert(Template(name: name, windows: windows))
        log("已保存模板「\(name)」，\(windows.count) 个窗口")
    }

    @objc private func applyTemplate(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let template = store.template(named: name) else { return }
        let screen = Geometry.screenUnderMouse()
        Restore.apply(template, on: screen)
        nameSpaceIfUnnamed(on: screen, as: template.name)
    }

    @objc private func chooseNewSpaceTemplate(_ sender: NSMenuItem) {
        store.setNewSpaceTemplate(sender.representedObject as? String)
    }

    @objc private func deleteTemplate(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("删除模板「\(name)」？", "Delete template “\(name)”?")
        alert.informativeText = L("删除后无法恢复。", "This can't be undone.")
        alert.addButton(withTitle: L("删除", "Delete"))
        alert.addButton(withTitle: L("取消", "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.delete(named: name)
        }
    }

    @objc private func togglePause() {
        paused.toggle()
        log(paused ? "已暂停自动套用" : "已恢复自动套用")
    }

    @objc private func openTemplateFolder() {
        NSWorkspace.shared.open(store.folderURL)
    }

    @objc private func openHomepage() {
        if let url = URL(string: Config.homepage) { NSWorkspace.shared.open(url) }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 弹窗

    private func askForName(info: String, defaultName: String) -> String? {
        askForText(title: L("保存当前桌面为模板", "Save Desktop as Template"), info: info,
                   defaultValue: defaultName, placeholder: L("模板名称", "Template name"),
                   button: L("保存", "Save"), allowEmpty: false)
    }

    /// 弹一个带输入框的对话框；取消返回 nil
    private func askForText(title: String, info: String, defaultValue: String,
                            placeholder: String, button: String, allowEmpty: Bool) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: L("取消", "Cancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty && !allowEmpty ? nil : text
    }

    private func showMessage(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // 不显示 Dock 图标，只有菜单栏图标
app.run()
