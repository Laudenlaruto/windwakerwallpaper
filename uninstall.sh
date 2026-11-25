#!/bin/zsh
# Stops the wallpaper agent and removes the installed files and screen saver.
# This deletes the images too, so pick a new wallpaper and screen saver in
# System Settings afterwards.
LABEL=local.timechangingwallpaper
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Screen Savers/Wind Waker Time.saver"
rm -rf "$HOME/Library/Application Support/TimeChangingWallpaper"
echo "Uninstalled."
