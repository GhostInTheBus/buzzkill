# MaleCNS brain circuit

`circuit.json` and `brain_points.json` replace the FlyWire-derived
`../data/circuit.json` and `../data/brain_points.json` with an extract of the
**MaleCNS v1.0** public connectome, so the whole app can run on one specimen
under one license (CC BY 4.0). Same schema; the app loads either
(`BUZZKILL_DATA=data-malecns`, or `./package.sh --malecns`).

## Reproduce

```sh
python3 etl_malecns.py /tmp/fly-male-cns --download   # fetches the three public tables (~1.1 GB)
python3 etl_malecns_brain.py /tmp/fly-male-cns        # writes this directory, ~20 s
tools/test-all.sh                                      # every suite, both extracts
```

Source tables (bulk "flat connectome", v1.0):
`body-annotations-male-cns-v1.0-minconf-0.5.feather`,
`body-neurotransmitters-male-cns-v1.0.feather`,
`connectome-weights-male-cns-v1.0-minconf-0.5.feather`. The URLs are embedded in
`circuit.json` under `files`.

## Selection — identical rules to `etl.py`

- **Core populations** by strict `type` match: LC4 (126), LPLC2 (185), DNp01 /
  Giant Fiber (2), DNa01 (2), DNa02 (2), DNp09 (2), DNg11 (6), MDN (4),
  DNp02/DNp04/DNp11 (6). Every one has an annotated side.
- **330 partners** ranked by synaptic weight to or from the core, restricted to
  brain super-classes: the 10 strongest for each small command population, then
  24 ascending and 16 sensory neurons reserved as body→brain targets, then the
  strongest remaining.
- **Edges**: every published connection with weight ≥ 5 between two members,
  signed by the consensus transmitter prediction.

The 16 reserved sensory partners come out as **auditory Johnston's organ
neurons** (15 JO-B1, 1 JO-A2; `class` mechanosensory, `subclass` auditory,
antennal nerve), 15 of them presynaptic to the Giant Fiber. The same selection
rule on the female FlyWire brain also lands on JO auditory neurons — the fly's
ears are among the Giant Fiber's strongest sensory inputs in both animals.

## What is modeled, not measured

- **Transmitter signs**: acetylcholine +1; GABA, glutamate, histamine −1;
  dopamine, serotonin, octopamine +0.5; unknown +1 (as `etl.py` does).
- **Display positions**: annotated soma location for 614 neurons. The 51 with
  no soma in the brain volume (sensory and ascending neurons) are drawn at the
  weight-averaged soma position of the circuit members they connect to.
  Position never enters the simulation.
- **Dynamics**: the leaky-integrate-and-fire model, its noise and baselines are
  the application's, unchanged.

## Fitting

Synapse counts are not comparable across connectomes — different detectors,
different animals. For the same circuit MaleCNS reports 2.3× the total synapses
of the FlyWire extract, about the same input onto the command neurons (ratios
0.9–1.4), 10× the excitation onto the Giant Fiber, and ~11,000 chemical
LC4/LPLC2 → GF synapses where FlyWire's signed total is negative. The app's
constants were tuned to FlyWire, so four model parameters are re-fit here and
stored in `circuit.json` under `model`:

| parameter | FlyWire | MaleCNS | why |
|---|---|---|---|
| `weightScale` | 0.0008 | **0.00018** | so the Giant Fiber is quiet at rest over minutes and its escape threshold sits where the FlyWire fit puts it |
| `gapJunctionBoost` (LC4/LPLC2 → GF) | 6 | **1** | the boost compensates for FlyWire under-counting that pathway; MaleCNS does not under-count it |
| `sensoryGapBoost` (JO → GF) | 6 | **3.5** | this coupling is electrical in the animal in any dataset; fit so a tap startles |
| `alertGain` (hearing) | 0.026 | **0.02** | same priming effect with few false alarms |

Fit objective, measured with `--gfstat` and the suites (40 seeds per point):

| | FlyWire | MaleCNS |
|---|---|---|
| spontaneous GF events per 100 s | 3 | 1 |
| escapes / 40 at loom 0.05, 0.10, 0.15, 0.20, 0.30, 0.50 | 0, 0, 0, 24, 40, 40 | 0, 1, 4, 40, 40, 40 |
| same, loud room | 1, 0, 1, 31, 40, 40 | 1, 2, 15, 40, 40, 40 |
| first GF spike after an abrupt loom | 4 ms | 4 ms |
| walk-drive / groom-drive duty | 42% / 11% | 38% / 8% |
| `--simtest`, `--behaviortest`, `--locomotortest`, `--populationtest` | pass | pass |

## Known differences from the FlyWire fit

- The male escape threshold is **sharper** (4/40 at loom 0.15, 40/40 at 0.20;
  FlyWire rises more gradually), and a little lower.
- During a *sustained* loom the male Giant Fiber keeps firing (~100 spikes in
  0.4 s) where the FlyWire circuit fires about twice and is then shut down by
  feed-forward inhibition. Excitation onto GF outweighs inhibition more in this
  extract. It does not change behavior — a takeoff is triggered by the first
  spike — but the brain window shows GF flashing through a lunge.
- These are properties of this extract and this fit, not claims about sex
  differences in fly physiology.
