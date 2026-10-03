#!/bin/zsh
# Merge the latest upstream desktop-fly into this branch. The engine files are
# upstream's; conflicts, if any, should be confined to the touch points listed
# in ENGINE.md. Run from the repo root on the branch you want updated.
set -e
cd "$(dirname "$0")/.."
git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/DenisSergeevitch/desktop-fly
git fetch origin master
echo "upstream: $(git log --oneline -1 origin/master)"
echo "local:    $(git log --oneline -1 HEAD)"
if git merge-base --is-ancestor origin/master HEAD; then echo "already up to date"; exit 0; fi
git merge --no-edit origin/master || {
  echo; echo "conflicts — see ENGINE.md for what this fork changed in each file:"; git diff --name-only --diff-filter=U; exit 1; }
./build.sh
for t in simtest behaviortest locomotortest; do ./DesktopFly --$t 2>&1 | grep -E '^FAIL|FAILURES|ALL .* PASS|^PASS: GF' | tail -1; done
