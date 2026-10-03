# Engine vs. game

This fork is a game built on Denis Shiryaev's
[desktop-fly](https://github.com/DenisSergeevitch/desktop-fly). The fly, its
brain and its body are the **engine** and stay his; everything that makes it a
pest is the **game** and lives in `Game/`, `Senses/` and `Audio/`.

| layer | files | owner |
|---|---|---|
| engine | `main.swift` (scene, CLI modes, `SignalBuilder`, `Coordinator`, `AppDelegate`), `FlyModel.swift`, `BeetleModel.swift`, `Sim.swift`, `Locomotor.swift`, `LegDynamics.swift`, `LocomotorTests.swift`, `BrainView.swift`, `Environment.swift`, `etl*.py`, `data/` | upstream |
| game | `Game/Game.swift` (orchestration), `Game/Population.swift` (arrivals, swarms, disperse, spook, shooing, pressure), `Game/Crumbs.swift`, `Game/Squish.swift`, `Game/Attraction.swift` (+ `--attracttest`), `Game/GameUI.swift` (menu, toggles, camera/sound/login, idle pause), `Game/GameWorld.swift` (the protocol the game sees) | this fork |
| senses | `Senses/CameraSense.swift` (webcam hand-pose), `Senses/HandLoom.swift` (hand → loom geometry) | this fork |
| audio | `Audio/FlySound.swift` (synthesized buzz + splat) | this fork |
| packaging | `package.sh`, `packaging/Info.plist` | this fork |

## Where the engine was touched

Keep this list short and current; it is what makes `tools/merge-upstream.sh` painless.

**`main.swift`**
- `Coordinator`: `handScene`/`handExtent` + a `HandLoom` instance; `let game = Game()`; `userIdle`; seven one-line entry points (`setAttract`, `setSquish`, `setSound`, `trySquish`, `pickUpCrumb`, `placeHeldCrumb`, `catchUpArrivals`); `game.preSim(...)` at the top of `advanceSimulation` and `game.drive(...)` before the sim step; hand loom folded into `sim.loomL/loomR/airPuff`; the hover-loom term in `computeLoom` is gated by cursor speed when attraction is on; `extension Coordinator: GameWorld`.
- `AppDelegate`: `lazy var gameUI`; `gameUI.restore()` after the menu is built; `gameUI.addItems(to:)` in the menu; `gameUI.idleTick` in the 30 Hz timer (idle also passed to `setAmbient`); `gameUI.consumeClick` before `trySquish` in the click monitor; a `screensDidWakeNotification` observer.
- CLI: `--attracttest`.

**`FlyModel.swift`**
- `attractTarget` + a body-level heading bias toward it while walking (after upstream's `if let motion … else { wander }` pair — do not split that pair).
- `attractHop(toward:bounds:dt:)` and `startFlight(… toward:)`: flight to an attractant, landing just short.
- `leaveChance` / `forceLeave` / `leaving` / `gone`: an escape from a threat may continue off screen; `land()` marks the fly gone.
- abdomen pivot moved to the waist (position compensated) + `abdWag` during grooming.

**`Sim.swift`**
- `attractTurn/attractDrive/attractGroom` inputs with `attractFwdGain`/`attractTurnGain`, injected per step into DNa01/02, DNp09, DNg11. Natural DNp09 is ~2 Hz; above ~20 Hz the leg circuit jams — measured, see `--attracttest`.

**`build.sh`**: the three new directories and `-framework AVFoundation -framework Vision`.

## Verifying after a change

```sh
./build.sh
./DesktopFly --simtest && ./DesktopFly --behaviortest && ./DesktopFly --locomotortest
SECS=30 ./DesktopFly --attracttest          # should arrive in a few seconds
./DesktopFly --populationtest               # game rules: cap curve, arrivals, disperse, spook, squish, crumbs
DESKTOPFLY_SWARM_TEST=40 DESKTOPFLY_FPS=1 ./DesktopFly   # 120 fps expected
```

The locomotor suite once caught a real regression here (wander jitter leaking
into motor mode from a misplaced `else`). Run all three every time.
