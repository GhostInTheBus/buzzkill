#!/bin/zsh
# Build DesktopFly and wrap it in a .app bundle.
#   ./package.sh            -> ./dist/DesktopFly.app
#   ./package.sh --install  -> also copies to /Applications and launches it
# Needs Xcode Command Line Tools (swiftc, sips, iconutil). No sudo.
set -e
cd "$(dirname "$0")"
./build.sh

DIST=dist; APP="$DIST/DesktopFly.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# The binary looks for data/ next to itself (Sim.swift findDataDir), so it
# lives in MacOS/, not Resources/.
cp DesktopFly "$APP/Contents/MacOS/DesktopFly"
cp -R data "$APP/Contents/MacOS/data"
cp packaging/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Icon: assets/fly.png -> AppIcon.icns
ICONSET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$ICONSET"
for n in 16 32 128 256 512; do
  sips -z $n $n assets/fly.png --out "$ICONSET/icon_${n}x${n}.png" >/dev/null
  sips -z $((n*2)) $((n*2)) assets/fly.png --out "$ICONSET/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"
echo "Built $APP"

if [[ "$1" == "--install" ]]; then
  TARGET=/Applications/DesktopFly.app
  pkill -x DesktopFly 2>/dev/null || true
  while pgrep -x DesktopFly >/dev/null; do sleep 0.1; done
  # Remove rather than overwrite: replacing a signed binary in place can get
  # it killed by the kernel on Apple Silicon.
  rm -rf "$TARGET"
  cp -R "$APP" "$TARGET"
  open "$TARGET"
  echo "Installed and launched $TARGET"
fi
