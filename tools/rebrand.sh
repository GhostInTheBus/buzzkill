#!/bin/zsh
# Give the game its own identity in one step:
#   tools/rebrand.sh "Buzzkill" com.example.buzzkill
# Renames the app (bundle name/display name/executable/menu title/defaults
# domain), rewrites package.sh and packaging/Info.plist, drafts README.md
# from docs/README.product.md, and leaves the engine files untouched. Review
# `git diff`, then commit. Upstream credit stays in NOTICE, the README and the menu.
set -e
cd "$(dirname "$0")/.."
NAME="${1:?app name}"; BUNDLE="${2:?bundle id, e.g. com.example.$(echo "$1" | tr 'A-Z ' 'a-z-')}"
EXE="${NAME// /}"
echo "renaming DesktopFly -> $NAME ($EXE, $BUNDLE)"
# packaging
sed -i '' -e "s#<string>DesktopFly</string>#<string>$EXE</string>#g" \
          -e "s#<string>local.desktopfly</string>#<string>$BUNDLE</string>#" packaging/Info.plist
# every DesktopFly token in the packaging script is the app, so rename them all
sed -i '' -e "s#DesktopFly#$EXE#g" package.sh
sed -i '' -e "s#-o DesktopFly #-o $EXE #" -e "s#Built ./DesktopFly#Built ./$EXE#" build.sh
# the menu bar title and header
sed -i '' -e "s#menu.addItem(withTitle: \"Desktop Fly\"#menu.addItem(withTitle: \"$NAME\"#" main.swift
# the README: product page from the template
sed -e "s#{{NAME}}#$NAME#g" -e "s#{{EXE}}#$EXE#g" docs/README.product.md > README.md
grep -q "^$EXE\$" .gitignore || echo "$EXE" >> .gitignore
echo "done. Review: git diff --stat; build: ./package.sh --install"
