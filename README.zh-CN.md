<div align="center">

# Spaceport

**打开桌面，马上摆好工作环境。**

把一个 macOS 桌面的布局（App、窗口位置、浏览器标签页、终端目录）存成模板，在任意桌面一键恢复。
新建的桌面能自动套用默认布局。

[![Build](https://github.com/Jyc323/Spaceport/actions/workflows/build.yml/badge.svg)](https://github.com/Jyc323/Spaceport/actions/workflows/build.yml)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

[English](README.md) · 简体中文

</div>

---

## 应用场景

Spaceport 是一个菜单栏小工具。macOS 的多桌面（Spaces）很适合把不同的工作分开，但它没有记忆：每个新桌面都是空的，需要重新布置桌面布局，打开并排序不同的应用程序。Spaceport可以自动化完成："套用前端项目的桌面布局预设，打开编辑器、开着 localhost 和文档的浏览器、再开一个在项目目录里的终端"。


## 功能

- **把桌面存成模板**：记录有哪些 App、每个窗口的位置，每个浏览器窗口的全部标签页，以及每个 Terminal 窗口的工作目录。
- **随处套用**：在菜单栏选一个模板，窗口就在当前桌面按原样打开；没运行的 App 会自动启动。
- **新桌面自动布置**：在 Mission Control 新建一个桌面并切过去，默认模板会自动套用。内置的默认模板是 Edge 和 Terminal 左右并排。
- **给桌面起名**：macOS 只显示「桌面 1、2、3…」，Spaceport 会在菜单栏显示自定义名字。
- **支持多显示器**：按显示器分别保存和套用；位置按比例记录，换显示器或分辨率也能用。
- **纯 JSON**：所有模板在一个文件里，可以手动编辑、备份、分享。
- **轻量、隐私**：不联网、不需要账号、不用关闭 SIP。

## 能恢复什么

| App | 恢复内容 |
|---|---|
| Microsoft Edge、Google Chrome、Brave、Chromium | 新窗口 + 全部标签页 + 选中的标签页 + 位置大小 |
| Terminal | 在原来的工作目录打开新窗口 + 位置大小 |
| 其他 App | 新窗口（通过它的 ⌘N 菜单）+ 位置大小 |

## 安装

> 当前状态：**早期预览版（v0.1）**，欢迎反馈和报 bug。

### 从源码编译（推荐，约 30 秒）

需要 macOS 12 以上和 Xcode Command Line Tools（`xcode-select --install`）。

```bash
git clone https://github.com/Jyc323/Spaceport.git
cd Spaceport
make install
```

会编译出 `Spaceport.app`，安装到 `~/Applications` 并设置为登录自启。菜单栏会出现一个分栏图标。

### 直接下载

从 [Releases](https://github.com/Jyc323/Spaceport/releases) 下载 `Spaceport-vX.Y.Z.zip`，解压后把 `Spaceport.app` 拖进「应用程序」。
目前还没有经过苹果公证，第一次打开会被拦截：去 **系统设置 → 隐私与安全性** 点「仍要打开」，或者运行：

```bash
xattr -dr com.apple.quarantine /Applications/Spaceport.app
```

## 快速上手

1. 把一个桌面布置成你喜欢的样子。
2. 点菜单栏图标 →「保存当前桌面为模板…」→ 起个名字，比如 `前端`。
3. 在任意别的桌面：「套用到当前桌面 → 前端」。
4. 可选：「新桌面自动套用 → 前端」，然后在 Mission Control 新建桌面并切过去。

## 菜单

| 菜单项 | 作用 |
|---|---|
| 当前桌面：xxx | 当前桌面的名字 |
| 重命名当前桌面… | 给当前桌面起名（留空可清除） |
| 保存当前桌面为模板… | 保存你点击的那块显示器上、当前桌面的窗口 |
| 套用到当前桌面 ▸ | 在这里打开并摆好模板里的窗口 |
| 新桌面自动套用 ▸ | 选择新桌面自动套用的模板，或「不自动套用」 |
| 删除模板 ▸ | 删除模板 |
| 暂停自动套用 | 临时停止自动布置新桌面 |
| 打开模板文件夹 | 打开 `~/Library/Application Support/Spaceport/` |

## 权限

| 权限 | 用途 | 什么时候会询问 |
|---|---|---|
| 自动化（Edge、Terminal 等） | 通过 AppleScript 读取和打开标签页、目录、窗口 | 第一次控制该 App 时 |
| 辅助功能 | 打开并摆放其他 App 的窗口 | 第一次套用包含其他 App 的模板时 |

Spaceport 不发起任何网络请求，所有数据都保存在本机 `~/Library/Application Support/Spaceport/templates.json`。

## 自定义

- **手动编辑模板**：在 `templates.json` 里改网址、目录或位置，每次打开菜单都会重新读取。`frame` 是占显示器可用区域的比例（0~1）。示例见 [`examples/templates.example.json`](examples/templates.example.json)。
- **行为开关**：`Sources/Spaceport/Support.swift` 里的 `Config`（比如 `requireEmptySpace`、支持的浏览器）。改完重新运行 `make install`。

## 已知限制

- **一次一个桌面**：不关闭 SIP 的话，macOS 不允许程序把窗口挪到其他桌面，所以模板会套用到你当前所在的桌面。
- 其他 App 只恢复新窗口和位置，不恢复窗口里打开的文件；没有 ⌘N 菜单的 App 打不开新窗口。
- 桌面名字只显示在 Spaceport 的菜单栏里，Mission Control 里仍是「桌面 N」；如果重启后名字没了，重新命名即可。
- 浏览器的无痕窗口、终端里正在运行的程序不会恢复。
- 如果有 App 被设置成「分配给所有桌面」，新桌面永远不是空的，不会自动套用：把 `Config` 里的 `requireEmptySpace` 改成 `false`。

## 常见问题

- **打开窗口时屏幕跳回了别的桌面**：关掉 *系统设置 → 桌面与程序坞 →「切换到某个应用程序时，会切换到包含该应用程序已打开窗口的空间」*。
- **没反应**：运行 `make logs`（或 `tail -f ~/Library/Logs/Spaceport.log`）看日志。出现 `-1743` 说明缺少自动化权限：*系统设置 → 隐私与安全性 → 自动化 → Spaceport*。
- **重新编译后又问权限**：正常，本地编译的 App 每次签名都不同。

## 原理

macOS 没有公开的"新建桌面"事件。Spaceport 监听桌面切换，并用 yabai、Hammerspoon 同样在用的只读 CoreGraphics 接口读取桌面 ID：切到一个没见过的 ID，就是新桌面。窗口列表来自 `CGWindowList`，浏览器标签页和终端目录通过 AppleScript 读取和恢复，其他 App 用辅助功能 API 摆放。

## 许可证

[MIT](LICENSE)
