# Buzzkill

**The only desktop pest where the kill is fair.**

A fruit fly lives on your Mac desktop and is run by a real fruit fly brain:
668 neurons and 18,968 synapses from the FlyWire connectome — the circuit that
spots danger and triggers escape — simulated live. Rush your cursor at it and
the actual Giant Fiber neuron fires and it bolts. Sneak up and you can squish
it. Drop a crumb and it flies over to eat. Leave for lunch and come back to a
swarm, which scatters the moment you move.

It knows where your windows are, when you're typing, what time it is, and
nothing about what any of it means.

Built on [desktop-fly](https://github.com/DenisSergeevitch/desktop-fly) by
**Denis Shiryaev** — the fly, the brain and the body are his. Buzzkill is the
world around it. See [NOTICE](NOTICE) and [ENGINE.md](ENGINE.md).

<!-- GIF: a squish, then a swarm scatter. ~10 s, ≤ 8 MB. -->

## Install

Download `Buzzkill.zip` from [Releases](https://github.com/GhostInTheBus/buzzkill/releases), unzip, drag to
`/Applications`. It is signed but not notarized, so the first launch is
refused; open **System Settings → Privacy & Security** and click **Open Anyway**
once (or `xattr -dr com.apple.quarantine /Applications/Buzzkill.app`).

Or build it (macOS 13+, Xcode Command Line Tools):

```sh
git clone https://github.com/GhostInTheBus/buzzkill.git && cd buzzkill
./package.sh --install
```

A 🪰 appears in the menu bar. Everything below lives there.

## How to play

- **Squish** — click a grounded fly. Approach slowly: a fast cursor trips the
  real looming → escape reflex before your click lands. Hitbox: Normal 26 px,
  Forgiving 34, Tiny 18 (`x`).
- **Misses are audible.** Swing and miss near a fly and you'll hear a short zip:
  it saw you.
- **Crumbs** (`m`) — carry one on the cursor, click to drop. Every fly comes.
- **Attract to Cursor** (`t`) — park the cursor; the fly flies over and grooms.
- **It stops when you do.** Idle a minute: 30 fps. Idle ten minutes (`i`:
  5/10/30/60): rendering, brain sim, camera and sound all stop — nothing burns
  while you sleep. The display waking (or any input) resumes it, and the
  flies that would have arrived stream in from the edges.
- **Swarms while you're away.** At the desk: a fly every few minutes, up to 4.
  Idle a minute or more: the cap climbs about 1.5 a minute, to 160. Come back
  and your first input scatters everything beyond 4. Shake the cursor hard
  (or wave at the camera) and the room empties until you've been idle again.
- **Camera Swat** (`c`, off by default) — the webcam becomes the fly's eyes.
  Plain frame differencing (no face or hand model) finds movement; how fast it
  *grows* in the frame drives the real LC4/LPLC2 looming detectors (expansion =
  something approaching), the half of the frame it's in picks the eye, a fast
  sweep is wind. Lunge at the screen and the Giant Fiber fires. On-device,
  frames compared and dropped. The one feature that needs a permission.
- **Stats** at the top of the menu: squished, got away, peak swarm, longest
  absence.

## What's real

The 668-neuron circuit and its signed synapses are real FlyWire wiring, run as
leaky-integrate-and-fire neurons at 1 kHz. Escape, steering, grooming and
backward walking are read off the actual cell types (GF, DNa01/02, DNg11, MDN).
A 1,045-neuron MaleCNS circuit drives the six legs.

Scripted: the body animation, flight paths, the approach to food (flies hop to
it — motor-mode walking covers ~1 px/s, measured in `--attracttest`), and the
whole game layer: crumbs, squishing, arrivals, scattering, stats. There is no
feeding or olfactory circuit in the data; the attractant is a synthetic input
in the same spirit as the author's loom.

## Diagnostics

```sh
./Buzzkill --simtest --behaviortest --locomotortest   # the engine's suites
./Buzzkill --populationtest                           # the game's rules
./Buzzkill --attracttest                              # attraction, headless
DESKTOPFLY_SWARM_TEST=200 DESKTOPFLY_FPS=1 ./Buzzkill  # stress (240 flies = 120 fps)
```

## License

MIT (code), see [LICENSE](LICENSE) and [NOTICE](NOTICE). Connectome data:
FlyWire CC BY-NC 4.0 and MaleCNS CC BY 4.0 — see `data/DATA_LICENSE.md`. The
non-commercial data license means this software is free and can't be sold.
