<div align="center">

# Spaceport

**Open a desktop, and your workspace sets itself up.**

Save the layout of a desktop — apps, window positions, browser tabs, Terminal folders — and bring it back on any desktop in one click.
New desktops can apply a default layout automatically.

[![Build](https://github.com/Jyc323/Spaceport/actions/workflows/build.yml/badge.svg)](https://github.com/Jyc323/Spaceport/actions/workflows/build.yml)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

English · [简体中文](README.zh-CN.md)

<!-- Add a 10–20 second demo here: docs/images/demo.gif
     (create a desktop → Edge + Terminal appear side by side → apply a saved "Frontend" layout) -->

</div>

---

## Use case

Spaceport is a small menu bar app. macOS Spaces are great for separating work, but they have no memory: every new desktop starts empty, and you have to set up the layout again — opening apps and arranging them one by one. Spaceport automates this: "apply the frontend project layout — open the editor, a browser with localhost and the docs, and a terminal in the project folder".

## Features

- **Save a desktop as a template** — which apps are open, where each window sits, every tab in each browser window, and the working folder of each Terminal window.
- **Apply anywhere** — pick a template from the menu bar and the windows open on the current desktop, in place. Apps that aren't running are launched.
- **Auto-setup for new desktops** — create a desktop in Mission Control, switch to it, and your default template is applied. The built-in default opens Edge and Terminal side by side.
- **Name your desktops** — macOS only shows "Desktop 1, 2, 3…". Spaceport shows a custom name in the menu bar.
- **Multi-monitor aware** — saves and applies per display; layouts are stored as proportions, so they survive a new monitor or resolution.
- **Plain JSON** — templates live in one file you can edit, back up or share.
- **Lightweight and private** — no network access, no account, no SIP changes.

## What gets restored

| App | Restored |
|---|---|
| Microsoft Edge, Google Chrome, Brave, Chromium | New window with all its tabs, the selected tab, position and size |
| Terminal | New window in the saved working folder, position and size |
| Any other app | New window (via its ⌘N menu item), position and size |

## Install

> Status: **early preview (v0.1)**. Feedback and bug reports are very welcome.

### Build from source (recommended, ~30 seconds)

Requires macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Jyc323/Spaceport.git
cd Spaceport
make install
```

This builds `Spaceport.app`, installs it to `~/Applications` and starts it at login. A split-window icon appears in the menu bar.

### Download

Grab `Spaceport-vX.Y.Z.zip` from [Releases](https://github.com/Jyc323/Spaceport/releases), unzip and move `Spaceport.app` to Applications.
The build isn't notarized yet, so macOS will block the first launch: open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Spaceport.app
```

## Quick start

1. Arrange a desktop the way you like it.
2. Menu bar icon → **Save Desktop as Template…** → give it a name, e.g. `Frontend`.
3. On any other desktop: **Apply to This Desktop → Frontend**.
4. Optional: **Template for New Desktops → Frontend**, then create a desktop in Mission Control and switch to it.

## Menu

| Item | What it does |
|---|---|
| Desktop: *name* | Name of the current desktop |
| Rename This Desktop… | Name the current desktop (leave empty to clear) |
| Save Desktop as Template… | Save the windows on the current desktop of the display you clicked |
| Apply to This Desktop ▸ | Open and arrange a template's windows here |
| Template for New Desktops ▸ | Template applied automatically to new desktops, or None |
| Delete Template ▸ | Remove a template |
| Pause Auto-Apply | Temporarily stop setting up new desktops |
| Open Templates Folder | Opens `~/Library/Application Support/Spaceport/` |

## Permissions

| Permission | Why | When it's requested |
|---|---|---|
| Automation (Edge, Terminal, …) | Read and open tabs, folders and windows via AppleScript | The first time Spaceport talks to that app |
| Accessibility | Open and position windows of other apps | The first time you apply a template with other apps |

Spaceport makes no network requests. Everything is stored locally in `~/Library/Application Support/Spaceport/templates.json`.

## Customising

- **Edit templates by hand** — change URLs, folders or positions in `templates.json`; Spaceport reloads it each time you open the menu. `frame` values are fractions (0–1) of the display's usable area. See [`examples/templates.example.json`](examples/templates.example.json).
- **Behaviour switches** — `Sources/Spaceport/Support.swift` → `Config` (e.g. `requireEmptySpace`, supported browsers). Run `make install` again after changing it.

## Limitations

- **One desktop at a time.** macOS doesn't let apps move windows to other desktops without disabling SIP, so a template is applied to the desktop you're on.
- Other apps get a new window and its position, not the documents that were open in it. Apps without a ⌘N menu item can't open a new window.
- Desktop names appear in Spaceport's menu bar item only; Mission Control still shows "Desktop N". If a name disappears after a restart, just rename the desktop.
- Private browsing windows and programs running inside Terminal aren't restored.
- If an app is assigned to "All Desktops", new desktops never look empty. Set `requireEmptySpace = false` in `Config`.

## Troubleshooting

- **The screen jumps back to another desktop when windows open** — turn off *System Settings → Desktop & Dock → "When switching to an application, switch to a Space with open windows for the application"*.
- **Nothing happens** — check `make logs` (or `tail -f ~/Library/Logs/Spaceport.log`). Error `-1743` means Automation permission is missing: *System Settings → Privacy & Security → Automation → Spaceport*.
- **Asked for permissions again after rebuilding** — expected: locally built apps get a new signature each build.

## How it works

macOS has no public "a desktop was created" event. Spaceport listens for desktop switches and reads desktop IDs through the same read-only CoreGraphics functions used by yabai and Hammerspoon. Switching to an ID it hasn't seen before means a new desktop. Windows are listed with `CGWindowList`, browser tabs and Terminal folders are read and restored via AppleScript, and other apps are positioned with the Accessibility API.


## License

[MIT](LICENSE)
