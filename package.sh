#!/bin/zsh
# Build DesktopFly and wrap it in a .app bundle.
#   ./package.sh              -> ./dist/DesktopFly.app (native arch)
#   ./package.sh --install    -> also copies to /Applications and launches it
#   ./package.sh --universal  -> arm64 + x86_64 binary (for releases)
# Needs Xcode Command Line Tools (swiftc, sips, iconutil, lipo). No sudo.
set -e
cd "$(dirname "$0")"
if [[ " $* " == *" --universal "* ]]; then
  # build.sh compiles for the host; do it once per arch and glue with lipo
  SRCS=(main.swift FlyModel.swift LegDynamics.swift Locomotor.swift LocomotorTests.swift BeetleModel.swift Sim.swift BrainView.swift Environment.swift Game/*.swift Senses/*.swift Audio/*.swift)
  FW=(-framework Cocoa -framework SceneKit -framework AVFoundation -framework Vision)
  for arch in arm64 x86_64; do
    swiftc -module-cache-path "${TMPDIR:-/tmp}/desktopfly-module-cache-$arch" -O -swift-version 5 \
      -target "$arch-apple-macos13.0" -o "DesktopFly-$arch" "${SRCS[@]}" "${FW[@]}"
  done
  lipo -create -output DesktopFly DesktopFly-arm64 DesktopFly-x86_64 && rm -f DesktopFly-arm64 DesktopFly-x86_64
  echo "Built universal ./DesktopFly ($(lipo -archs DesktopFly))"
else
  ./build.sh
fi

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

if [[ " $* " == *" --install "* ]]; then
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
