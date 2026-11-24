#!/bin/bash
# Build Spaceport, copy it to ~/Applications and start it at login.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="$HOME/Applications/Spaceport.app"
LABEL="local.spaceport"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/Spaceport.log"
UID_NUM="$(id -u)"

./scripts/build.sh "$@"

echo "→ Stopping any running copy"
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true

echo "→ Installing to $DEST"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto build/Spaceport.app "$DEST"

echo "→ Starting at login"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$DEST/Contents/MacOS/Spaceport</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict><key>SuccessfulExit</key><false/></dict>
    <key>ProcessType</key><string>Interactive</string>
    <key>StandardErrorPath</key><string>$LOG</string>
    <key>StandardOutPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

echo ""
echo "✅ Spaceport is running — look for the split-window icon in the menu bar."
echo "   macOS will ask for Automation (and later Accessibility) permission the first time."
echo "   Logs: $LOG"
