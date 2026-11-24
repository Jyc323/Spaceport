#!/bin/bash
# Remove Spaceport. Your templates in ~/Library/Application Support/Spaceport are kept.
LABEL="local.spaceport"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/Spaceport.app"
rm -f "$HOME/Library/Logs/Spaceport.log"
tccutil reset AppleEvents local.spaceport >/dev/null 2>&1 || true
tccutil reset Accessibility local.spaceport >/dev/null 2>&1 || true

echo "✅ Spaceport removed. Templates are kept in ~/Library/Application Support/Spaceport/"
