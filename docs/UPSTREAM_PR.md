# Draft: upstream PR for the packaging script (not sent)

Branch to open from: `packaging` (clean: `package.sh`, `packaging/Info.plist`,
README install subsection; no senses, no game). Target: `DenisSergeevitch/desktop-fly:master`.

Before opening: `git checkout packaging && tools/merge-upstream.sh` so it's
rebased on current master; drop the Releases link to this fork from the README
hunk (that's fork-specific).

## Title
Add package.sh: build a .app bundle (icon, Info.plist, /Applications install)

## Body
Thanks for this — it's the most delightful thing on my desktop.

The README's install path leaves users with a bare binary they run from a
terminal. This adds `package.sh`, which wraps the existing `build.sh` output
into `DesktopFly.app`:

- `data/` placed next to the executable (`Contents/MacOS/data`), where
  `findDataDir` already looks, so nothing in the sources changes.
- `AppIcon.icns` generated from `assets/fly.png` with `sips` + `iconutil`.
- `packaging/Info.plist` with `LSUIElement` (no Dock icon — the app already
  sets `.accessory`), `LSMinimumSystemVersion 13.0`, bundle id `local.desktopfly`.
- `./package.sh --install` kills a running instance, removes the old bundle
  rather than overwriting the signed binary in place (which the kernel can
  kill on Apple Silicon), copies, and launches.

No new dependencies beyond the Command Line Tools; no permissions or
entitlements. Ad-hoc signed by the linker as before.

Happy to rename, move, or drop the README hunk if you'd rather keep the
install docs as they are.
