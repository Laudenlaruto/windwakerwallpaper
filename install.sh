#!/bin/zsh
# Installs the time-changing Wind Waker wallpaper and screen saver for the current user.
#   ./install.sh [path/to/imgs]
# Without an argument it uses the images in this repo's imgs/ folder, then
# already-installed images, and only as a last resort downloads them from the
# upstream GitHub repo.
set -euo pipefail

HERE=${0:A:h}
DEST="$HOME/Library/Application Support/TimeChangingWallpaper"
SAVER="$HOME/Library/Screen Savers/Wind Waker Time.saver"
LABEL=local.timechangingwallpaper
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BUILD=$(mktemp -d)

have_images() { [[ -f "$1/1.jpg" && -f "$1/200.jpg" ]] }

mkdir -p "$DEST/imgs" "$HOME/Library/LaunchAgents" "$HOME/Library/Screen Savers"

# --- Images
if [[ $# -ge 1 ]]; then
  echo "Copying images from $1"
  ditto "$1" "$DEST/imgs"
elif have_images "$HERE/imgs" && [[ "${HERE:A}/imgs" != "${DEST:A}/imgs" ]]; then
  echo "Copying images from this repo"
  ditto "$HERE/imgs" "$DEST/imgs"
elif have_images "$DEST/imgs"; then
  echo "Images already installed"
else
  git clone --depth 1 https://github.com/JayexDesigns/time-changing-wallpaper "$BUILD/repo"
  ditto "$BUILD/repo/imgs" "$DEST/imgs"
fi
have_images "$DEST/imgs" || { echo "images 1.jpg..200.jpg not found"; exit 1; }

# --- Build
echo "Compiling"
swiftc -O "$HERE/Schedule.swift" "$HERE/main.swift" -o "$BUILD/timewall"
swiftc -O -emit-library -Xlinker -bundle -module-name WindWakerTime \
  "$HERE/Schedule.swift" "$HERE/Saver.swift" -framework ScreenSaver -o "$BUILD/WindWakerTime"

# --- Wallpaper tool
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && sleep 2 || true
cp "$BUILD/timewall" "$DEST/timewall"
if [[ "$HERE" != "${DEST:A}" ]]; then
  cp "$HERE"/{Schedule.swift,main.swift,Saver.swift,install.sh,uninstall.sh} "$DEST/"
  mkdir -p "$DEST/assets" && cp "$HERE"/assets/*.png "$DEST/assets/"
  chmod +x "$DEST/install.sh" "$DEST/uninstall.sh"
fi
rm -f "$DEST/timewall.swift"  # from the first version

# --- Screen saver bundle (images are APFS clones of the installed ones: no extra space)
rm -rf "$SAVER"
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources/imgs"
cp "$BUILD/WindWakerTime" "$SAVER/Contents/MacOS/WindWakerTime"
cp "$HERE"/assets/thumbnail{,@2x}.png "$SAVER/Contents/Resources/"
cp -c "$DEST"/imgs/*.jpg "$SAVER/Contents/Resources/imgs/" 2>/dev/null || cp "$DEST"/imgs/*.jpg "$SAVER/Contents/Resources/imgs/"
cat > "$SAVER/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.timechangingwallpaper.saver</string>
  <key>CFBundleName</key><string>Wind Waker Time</string>
  <key>CFBundleDisplayName</key><string>Wind Waker Time</string>
  <key>CFBundleExecutable</key><string>WindWakerTime</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>NSPrincipalClass</key><string>TimeWallView</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$SAVER"

# --- LaunchAgent: keeps timewall running so it reacts to Space/display changes
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$DEST/timewall</string><string>--watch</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$DEST/timewall.log</string>
  <key>StandardErrorPath</key><string>$DEST/timewall.log</string>
</dict>
</plist>
EOF

: > "$DEST/timewall.log"
for i in 1 2 3; do
  launchctl bootstrap "gui/$(id -u)" "$PLIST" && break
  [[ $i == 3 ]] && { echo "launchctl bootstrap failed"; exit 1; }
  sleep 2
done
rm -rf "$BUILD"
echo "Installed. Wallpaper now: $("$DEST/timewall" --print)"
echo "Screen saver installed as 'Wind Waker Time' — pick it in System Settings > Screen Saver."
