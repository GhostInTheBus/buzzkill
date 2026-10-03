<p align="center">
  <img src="assets/fly.png" width="340" alt="DesktopFly — a 3D fruit fly">
</p>

<h1 align="center">DesktopFly 🪰</h1>

<p align="center">
A 3D fruit fly that lives on your macOS desktop, with spiking simulations
built from <a href="https://codex.flywire.ai">FlyWire</a> brain wiring and
the <a href="https://male-cns.janelia.org/">MaleCNS</a> brain-to-leg network.
It combines identified neural circuits with modeled senses, joints and behavior.
</p>

<p align="center">
  <img src="assets/brain.png" width="560" alt="Live brain window: 23,210 real neuron positions, spikes flashing">
</p>

<p align="center"><sub>
The fly's brain window: 23,210 real neuron soma positions from FlyWire v783,
with live spikes flashing at real neuron locations. The two glowing yellow
markers are the Giant Fibers — the escape command neurons. Click any region
to stimulate it.
</sub></p>

## Changelog

### 1.1.0 — 2026-09-05

- **Motor-driven legs:** added a MaleCNS v1.0 extract with 1,045 neurons and
  17,224 measured connections. Simulated motor activity drives articulated
  joints, forward/backward stepping and steering, with joint and foot-contact
  feedback. The existing FlyWire brain connects through a modeled interface.
- **Smooth behavior changes:** walking, grooming, sleep and flight preserve the
  current joint pose. Returning to walking carries that pose and its velocity
  into the mechanics. Body turns, landing pitch and wing folding now ease
  between states instead of snapping.
- **Wing and ledge fixes:** raised and reshaped wing hinges prevent body
  clipping. Moving a window out from under the fly triggers takeoff instead of
  teleporting it to the window's new edge; threat turns stop overriding later
  steering once the dart ends.
- **Consistent timing and Windows support:** the full neural/body feedback loop
  runs at 120 Hz independently of display refresh. The Electron port shares the
  motor mechanics and transition fixes; the beetle body remains macOS-only.
- **Validation and provenance:** added reproducible extraction, source hashes,
  separate MaleCNS data licensing and 18 locomotor checks on each platform.
  All native and JavaScript suites pass. Native motion sequences were visually
  reviewed; Windows-native sensing still needs verification on Windows.

The new circuit adds measured anatomy; neural physiology, sensory tuning and
muscle mechanics remain modeled. See [evaluation and limitations](EVALUATION.md)
and [data provenance](data/LOCOMOTOR_PROVENANCE.md).

## What's real

- **23,210 neuron soma positions** (of 139,255 in FlyWire v783) render the
  rotating brain window, colored by super-class (FlyWire's coarse cell-type
  grouping).
- **A 668-neuron female FlyWire circuit with 18,968 real connection rows** (synapse
  counts, signed by neurotransmitter prediction) runs as a 1 kHz
  leaky-integrate-and-fire (LIF) simulation:
  - **LC4 (104) + LPLC2 (210)** looming-detector visual neurons
  - **DNp01 / Giant Fiber (GF) (2)** — the escape command neuron
  - **DNa01 + DNa02 (4)** steering neurons · **DNp09 (2)** forward walking
  - **DNg11 (6)** grooming · **MDN (4)** backward walking ("moonwalker")
  - **DNp02/DNp04/DNp11 (6)** escape-maneuver (wing) neurons
  - their 330 strongest partners, including ascending (proprioceptive) and
    sensory (wind) neurons
- **A 1,045-neuron MaleCNS locomotor circuit** adds 16 descending neurons,
  622 VNC interneurons, 220 identified leg motor neurons, 153 leg sensory
  neurons and 34 ascending neurons. Its **17,224 real directed connections
  represent 708,689 synaptic contacts**, with actual paths from descending
  neurons through the ventral nerve cord (VNC) to all six legs.
- **The escape trigger uses simulated Giant Fiber spikes.** Cursor approach
  drives the LC4/LPLC2 pathway, and a GF spike requests takeoff. Sensory gain,
  electrical-coupling approximation and delays are configured model parameters;
  the resulting reaction time is not a measurement of a living fly.

The body is procedural. The experimental MaleCNS path drives articulated leg
joints and receives joint/contact feedback. Flight, wing-beat, grooming and
sleep retain modeled animation and state rules. This is not a full CNS or a
biologically calibrated walking simulation.

## Installation

Requirements: **macOS 13+**, Xcode Command Line Tools (Swift 5.9+).
No permissions or entitlements needed — everything it senses
(cursor, window frames, clicks-as-taps, thermal state) is permission-free.

```sh
git clone https://github.com/DenisSergeevitch/desktop-fly.git
cd desktop-fly
./build.sh
./DesktopFly
```

A 🪰 item appears in the menu bar; quit from there. The fly wanders your
desktop on a transparent, click-through overlay — it never intercepts your
mouse or keyboard.

### macOS .app bundle

To run it as a regular app (icon, `/Applications`, no terminal):

```sh
./package.sh --install   # builds dist/DesktopFly.app, copies it to /Applications, launches it
```

Or grab `DesktopFly-<version>.zip` from the
[Releases](https://github.com/GhostInTheBus/desktop-fly/releases) page of this fork.
The bundle is ad-hoc signed, not notarized, so on first launch of a downloaded
copy macOS will say it's damaged or from an unidentified developer. Clear the
quarantine flag and it opens normally:

```sh
xattr -dr com.apple.quarantine /Applications/DesktopFly.app
```

The packaging script and bundle are this fork's only addition. The fly — the
connectome extraction, neural model, body, everything you actually see — is
the work of [Denis Shiryaev](https://github.com/DenisSergeevitch) in the
[upstream repo](https://github.com/DenisSergeevitch/desktop-fly).

### Fork additions (`senses` branch)

All opt-in or toggleable from the 🪰 menu. The fly, its brain and body are
unchanged and are the work of [Denis Shiryaev](https://github.com/DenisSergeevitch).
What is and isn't neurons is spelled out, because the whole point of this app is
that the behavior comes from real wiring.

- **Attract to Cursor** (`t`, off by default) — the cursor as a sugar drop. The
  real steering (DNa01/02), forward-walking (DNp09) and grooming (DNg11)
  neurons get a light synthetic drive so the brain window shows the pull and
  the fly grooms on arrival. The approach itself is **scripted flight**: with
  the MaleCNS leg circuit driving the body, walking covers about 1 px/s
  (measured headless, see `--attracttest`), so the fly hops to the target and
  lands just short of it, the way a real fly reaches food. A parked cursor no
  longer counts as a looming threat while this is on; a lunging one still does.
- **Pick Up a Crumb** (`m`) — a crumb rides your cursor; your next click drops
  it (that click never squishes). Every fly converges on it and feeds; a crumb
  lasts about 80 s per fly. Finishing crumbs makes new flies arrive sooner.
- **Squish on Click** (`k`, on) — click a grounded fly (26 px hitbox) and it
  becomes a splat with the flattened fly in it, solid for 2.5 minutes, fading
  over the next. You have to earn it: a fast cursor trips the real escape
  circuit first.
- **Swarms while you're away** — newcomers fly in from a screen edge. At the
  desk: every 1.5–4 minutes, up to 4. Idle a minute or more: the cap climbs
  with time gone (1.5 per minute: ~50 after half an hour, ~95 after an hour, 160 by 1h45) and flies attract
  flies — each one present shortens the next wait 8%, floor 5 s. Squishing
  raises a persisted "population pressure" that slows arrivals; it decays over
  a day. Stress-tested at 240 flies: 120 fps, ~60% of one core.
- **Coming back** — your first input after being away scatters everything
  beyond the home population of 4: they take off away from the cursor and
  leave the screen. The brain fly startles but stays.
- **Idle pause** — after an hour without input the scene stops rendering
  (GPU idle; camera and sound stop too). It resumes when the display wakes or
  on input, and the arrivals that would have happened stream in from the
  edges, so the swarm is there to be seen before you scatter it.
- **Shooing** — when a fly escapes your cursor or hand it may keep going and
  leave the screen for good instead of landing elsewhere (25% alone, up to 85%
  in a crowd). Clear a swarm by chasing it.
- **Launch at Login** (`l`) — via `SMAppService`; only from the installed .app.
- **Grooming wag** — the abdomen wags in bursts while grooming (DNg11-driven).
- **Sound** (`u`, on, quiet) — a synthesized wingbeat buzz while a fly is
  airborne (pitch follows effort, panned to its position) and a splat on squish.
  No audio files; everything is generated in `FlySound.swift`.
- **Camera Swat** (`c`, off) — the webcam watches for a hand (Vision hand-pose,
  on-device, frames discarded) and feeds it into the same loom / air-puff
  pathway as the cursor, so a swat at the screen triggers the real giant-fiber
  escape. The one feature that needs a permission (Camera).

Diagnostics added: `./DesktopFly --attracttest` (headless gain sweep with the
locomotor active; `FWD`, `TURN`, `SECS`, `ATTRACT=0` env vars) and
`DESKTOPFLY_ATTRACT_DEBUG=1` for a per-second brain/body readout.

### Windows

An Electron + three.js port with the same connectome extracts, neural models, and
the same test suites lives in [`windows/`](windows/) (contributed by
[@MikeMike88](https://github.com/MikeMike88)). Requires Windows 10/11 and
[Node.js](https://nodejs.org) 18+:

```sh
cd desktop-fly/windows
npm install
npm start          # tray icon 🪰; quit from there
npm test           # all three suites, headless
```

See [windows/README.md](windows/README.md) for the macOS→Windows mapping
table and platform notes (the fly there roams all monitors on its own).
The optional stag-beetle body is macOS-only for now.

## Controls (menu bar 🪰)

| item | effect |
|---|---|
| Pause / Resume | freeze the world |
| Show/Hide Brain | toggle the live brain window |
| Escape Test (loom) | inject a looming stimulus, watch the GF fire |
| Move to Next Display | hop the fly across monitors (shown when >1 display) |
| Add / Remove Fly | extra flies (only fly #1 carries the brain) |
| Scare Flies | startle everyone |
| Body: Fruit Fly / Stag Beetle | swap the body geometry — behavior is unchanged |

<p align="center">
  <img src="assets/beetle.png" width="300" alt="The optional stag-beetle body">
</p>

<p align="center"><sub>
The same connectome, the same state machine, a different shell. The behavior
layer only ever touches the body through one struct, so a second geometry drops
in without a line of behavior code: the elytra open when it flies or when the
escape descending neurons fire a grounded threat posture, and the membranous
hindwings underneath are the surfaces that actually beat.
</sub></p>

**The brain window is interactive**: hovering pauses the rotation; clicking a
region "optogenetically" stimulates the ~60 nearest circuit neurons for
400 ms. Spikes propagate through the extracted FlyWire graph and the configured
body interface: the Giant Fiber requests escape, DNg11 requests grooming, and
an asymmetric DNa01/02 stimulus changes the steering drive.

## How real neurons drive the body

| body behavior | driven by |
|---|---|
| escape takeoff | DNp01 giant fiber spike |
| walk vs. rest | DNp09 rate through a modeled state threshold |
| leg activation and grounded movement | MaleCNS motor rates → modeled joints and foot contacts |
| steering drive | DNa01+DNa02 activity passed to the male descending populations |
| grooming | DNg11 rate |
| backward scoot | MDN burst |
| nervous darting | LC4/LPLC2 population rate |
| wing-beat effort, threat wing-raise | DNp02/04/11 rate |
| spontaneous takeoff | whole-population arousal |

FlyWire population rates drive corresponding male descending cell types through
an explicit **modeled interface between two specimens**. Within MaleCNS,
published connections link descending neurons, VNC interneurons, motor neurons,
leg sensory neurons and ascending feedback. There are no invented
cross-specimen synapses in the data.

Motor channels use named tibial and trochanteral flexors/extensors, sternal
anterior/posterior coxal rotators, and named promotor/remotor groups. Body joint angles, velocities and contact/load estimates
feed leg-local sensory inputs. Peripheral nerve and receptor-class identities
are measured annotations; joint tuning, muscle forces and the conversion of
those measurements into current are modeling choices. Fast cursor motion
continues to stimulate the original FlyWire sensory pathway.

## Desktop ecology (all permission-free macOS senses)

- **Window terrain**: window top edges are ledges — the fly lands on them,
  walks along them, follows nearby edge movement, and takes off when its
  supporting edge moves away or closes.
- **Window looms**: a window appearing near the fly feeds the looming
  pathway; the circuit decides whether to flee your dialogs.
- **Clicks are substrate taps**; clicking next to the fly startles it through
  the wind→GF pathway. **Typing is vibration** (idle-time API — knows *when*
  keys were pressed, never which).
- **Circadian rhythm**: dawn/dusk activity peaks, midday siesta, night
  quiescence. **Sleep**: idle at night → it sleeps, breathing slowly, with
  raised arousal threshold; it grooms after waking.
- **Temperature**: flies are ectotherms — a hot Mac is a faster fly.

## Regenerating the data

`data/` ships with compact derived files. To rebuild them from the raw
FlyWire Codex dumps (~60 MB download):

```sh
mkdir -p /tmp/flywire && cd /tmp/flywire
B=https://storage.googleapis.com/flywire-data/codex/data/fafb/783
curl -O "$B/classification.csv.gz" -O "$B/coordinates.csv.gz" \
     -O "$B/connections.csv.gz" -O "$B/consolidated_cell_types.csv.gz"
cd - && python3 etl.py /tmp/flywire
```

The separate MaleCNS extractor downloads three public Feather tables (~1.11 GB)
into a temporary directory and regenerates the compact locomotor graph:

```sh
python3 -m pip install numpy pandas pyarrow
python3 etl_malecns.py /tmp/fly-male-cns --download
```

It writes `data/locomotor_circuit.json` and `data/locomotor_report.json`.
The circuit records exact source URLs, SHA-256 hashes, native body IDs and
annotations. The report records real descending-to-motor paths and omitted
input coverage. See [data/LOCOMOTOR_PROVENANCE.md](data/LOCOMOTOR_PROVENANCE.md)
for the extraction rules and data/model boundary. Keep raw downloads outside
the repository; the original FlyWire files are not changed by this extractor.

## Diagnostics

```sh
./DesktopFly --simtest        # circuit invariants and stimulus responses
./DesktopFly --behaviortest   # end-to-end neural/body checks
./DesktopFly --locomotortest  # actual MaleCNS closed loop, direction, lesions, frame-rate checks
./DesktopFly --snapshot f.png  # offscreen body render (3/4 perspective)
./DesktopFly --snapshot f.png --top [--flying] [--beetle]   # the overlay's own
                               # top-down orthographic view, the one users see
./DesktopFly --brainshot b.png # offscreen brain render
./DesktopFly --snapshot walk.png --top --walking # pose from the live motor circuit
```

## What's modeled vs. measured

The connectomes supply anatomy and contact counts, not a working physiological
simulation. LIF dynamics, excitability, synaptic signs/delays, electrical-coupling
boosts, rate normalization, the interface between specimens, sensory tuning,
muscle mechanics and behavioral thresholds are configured models.

MaleCNS retains original neurotransmitter predictions and raw counts. The
current sign convention is ACh+, GABA− and Glu−; unresolved/modulatory edges
have zero direct current while retaining their source contacts. Motor channels
retain only part of their full incoming contacts; the report provides exact
coverage by leg and channel. Other inputs and much of the complete nervous
system are omitted.

Connectivity alone does not establish alternating gait, stable balance or
realistic muscle recruitment: a network may co-contract or settle under tonic
drive. The motor evaluation requires sustained stepping after startup, physical
backward motion, causal steering and loss of propulsion after motor silencing.
The complete sensor/neuron/body feedback loop runs at 120 Hz independently of
render refresh, with 1 kHz neurons and 600 Hz mechanical substeps. Muscle force
and relaxation parameters are calibrated model choices; see [evaluation](EVALUATION.md).
Anatomical path checks and software behavior tests do not demonstrate
agreement with measured fly locomotion. The brain window continues to show
the FlyWire visualization rather than all 1,713 simulated cells together.

## License & citation

Code is MIT. The original FlyWire-derived `brain_points.json` and `circuit.json`
are **CC BY-NC 4.0**. The MaleCNS-derived `locomotor_circuit.json` and
`locomotor_report.json` are **CC BY 4.0** — see
[data/DATA_LICENSE.md](data/DATA_LICENSE.md).
If you use this, cite:

- Dorkenwald, S. et al. *Neuronal wiring diagram of an adult brain.* Nature 634, 124–138 (2024). https://doi.org/10.1038/s41586-024-07558-y
- Schlegel, P. et al. *Whole-brain annotation and multi-connectome cell typing of Drosophila.* Nature 634, 139–152 (2024). https://doi.org/10.1038/s41586-024-07686-5
- [MaleCNS v1.0 dataset](https://male-cns.janelia.org/), by FlyEM/HHMI Janelia,
  University of Cambridge, MRC Laboratory of Molecular Biology and Google Research.
