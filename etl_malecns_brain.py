#!/usr/bin/env python3
"""Extract the escape/steering brain circuit and a soma point cloud from MaleCNS v1.0.

A CC BY 4.0 replacement for the FlyWire-derived data/circuit.json and
data/brain_points.json (CC BY-NC 4.0). Same selection rules and the same output
schema as etl.py, so the app loads either:

    python3 etl_malecns_brain.py /tmp/fly-male-cns          # raw tables (see etl_malecns.py --download)
    BUZZKILL_DATA=data-malecns ./Buzzkill --simtest

Selection (mirrors etl.py):
  * core populations by strict `type` match;
  * partners ranked by synaptic weight to/from the core, with the 10 strongest
    partners reserved for each small command population, 24 ascending and 16
    sensory neurons reserved as body->brain feedback targets, then the strongest
    remaining up to 330;
  * edges are published connections with weight >= 5 between members, signed by
    the consensus neurotransmitter prediction.

Modeling choices that are NOT in the source data:
  * the sign/strength mapping of transmitters (ACh +1, GABA/Glu/histamine -1,
    monoamines +0.5, unknown +1 as in etl.py);
  * display positions: soma location where annotated; neurons without a soma in
    the CNS volume (sensory, ascending) are drawn at the weight-averaged soma
    position of the circuit members they connect to. Position never affects
    the simulation.
"""
import json, sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.ipc as ipc

RAW = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/fly-male-cns")
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent / "data-malecns"
OUT.mkdir(parents=True, exist_ok=True)
BASE = "https://storage.googleapis.com/flyem-male-cns/v1.0/connectome-data/flat-connectome/"
FILES = {
    "annotations": "body-annotations-male-cns-v1.0-minconf-0.5.feather",
    "neurotransmitters": "body-neurotransmitters-male-cns-v1.0.feather",
    "weights": "connectome-weights-male-cns-v1.0-minconf-0.5.feather",
}
CORE_TYPES = {          # type -> role (identical to etl.py)
    "LC4": "lc4", "LPLC2": "lplc2", "DNp01": "gf", "DNa02": "dna02", "DNa01": "dna01",
    "DNp09": "dnp09", "DNg11": "dng11", "MDN": "mdn",
    "DNp02": "escw", "DNp04": "escw", "DNp11": "escw",
}
NT_SIGN = {"acetylcholine": 1.0, "gaba": -1.0, "glutamate": -1.0, "histamine": -1.0,
           "dopamine": 0.5, "serotonin": 0.5, "octopamine": 0.5}
# Model parameters fit to this extract (see "Fitting" in data-malecns/PROVENANCE.md).
# Synapse counts are not comparable across connectomes: MaleCNS reports 2.3x the
# total synapses of the FlyWire extract for the same circuit and ~11,000 chemical
# LC4/LPLC2->GF synapses where FlyWire's net count is negative. So (a) the
# gap-junction boost the FlyWire fit needs on that pathway is dropped, and (b)
# the global weight scale is re-fit so the Giant Fiber is quiet at rest over
# minutes and its escape threshold sits where the FlyWire fit puts it.
MODEL = {"weightScale": 0.00018,      # global synaptic weight per synapse
         "gapJunctionBoost": 1.0,      # LC4/LPLC2 -> GF: chemical counts suffice here
         "sensoryGapBoost": 3.5,       # JO auditory -> GF: electrical coupling, as in the animal
         "alertGain": 0.02}            # hearing drive into the auditory neurons
MAX_PARTNERS = 330
MAX_POINTS = 22000
MIN_WEIGHT = 5
# MaleCNS superclass -> the super_class names the app already knows (etl.py SUPER_CLASSES)
SUPER = {"ol_intrinsic": "optic", "cb_intrinsic": "central", "cb_sensory": "sensory",
         "sensory_ascending": "sensory", "visual_projection": "visual_projection",
         "visual_centrifugal": "visual_centrifugal", "descending_neuron": "descending",
         "ascending_neuron": "ascending", "cb_motor": "motor", "cb_endocrine": "endocrine"}
SUPER_CLASSES = ["optic", "central", "sensory", "visual_projection", "visual_centrifugal",
                 "descending", "ascending", "motor", "endocrine"]
# classes whose somata lie in the brain: used for the point cloud and the display transform
BRAIN_SOMA = ["ol_intrinsic", "cb_intrinsic", "visual_projection", "visual_centrifugal",
              "descending_neuron", "cb_motor", "cb_endocrine"]

ann = pd.read_feather(RAW / FILES["annotations"]).set_index("bodyId", drop=False)
assert ann.index.is_unique
nt = pd.read_feather(RAW / FILES["neurotransmitters"]).set_index("body")["consensus_nt"]

# --- core populations --------------------------------------------------------
core_rows = ann[ann.type.isin(CORE_TYPES)]
core = {int(b): CORE_TYPES[t] for b, t in zip(core_rows.index, core_rows.type)}
counts = Counter(core_rows.type)
print("core populations:", dict(counts))
for must in ("LC4", "LPLC2", "DNp01"):
    assert counts.get(must), f"missing core population {must}"
assert core_rows.somaSide.isin(["L", "R"]).all(), "core neuron without an annotated side"

pool = ann[ann.superclass.isin(SUPER)]
pool_ids = pa.array(pool.index.to_numpy())
core_ids = pa.array(np.array(sorted(core), dtype=pool.index.dtype))

# --- pass 1: every published edge (weight >= 5) touching the core, within the pool
reader = ipc.open_file(pa.memory_map(str(RAW / FILES["weights"])))
keep, rows_seen = [], 0
for i in range(reader.num_record_batches):
    b = reader.get_batch(i)
    rows_seen += len(b)
    w = b["weight"].to_numpy()
    pre_c = pc.is_in(b["body_pre"], value_set=core_ids).to_numpy(zero_copy_only=False)
    post_c = pc.is_in(b["body_post"], value_set=core_ids).to_numpy(zero_copy_only=False)
    pre_p = pc.is_in(b["body_pre"], value_set=pool_ids).to_numpy(zero_copy_only=False)
    post_p = pc.is_in(b["body_post"], value_set=pool_ids).to_numpy(zero_copy_only=False)
    m = (w >= MIN_WEIGHT) & pre_p & post_p   # all pool-internal edges; members are chosen from the pool
    if m.any():
        keep.append(pa.Table.from_batches([b.filter(pa.array(m))]).select(["body_pre", "body_post", "weight"]))
edges_all = pa.concat_tables(keep).to_pandas()
print(f"weights rows: {rows_seen:,}; pool-internal edges (w>={MIN_WEIGHT}): {len(edges_all):,}")

pre_core = edges_all.body_pre.isin(core)
post_core = edges_all.body_post.isin(core)
partner_strength = defaultdict(int)
strength_by_role = defaultdict(lambda: defaultdict(int))
for pre, post, w in edges_all[pre_core & ~post_core].itertuples(index=False):
    partner_strength[post] += w; strength_by_role[core[pre]][post] += w
for pre, post, w in edges_all[post_core & ~pre_core].itertuples(index=False):
    partner_strength[pre] += w; strength_by_role[core[post]][pre] += w
print(f"candidate partners: {len(partner_strength):,}")

sclass = pool.superclass.map(SUPER).to_dict()
ranked = [r for r, _ in sorted(partner_strength.items(), key=lambda kv: (-kv[1], kv[0]))]
partners, seen = [], set()
def take(cands, k):
    n = 0
    for r in cands:
        if r in seen:
            continue
        seen.add(r); partners.append(r); n += 1
        if n == k:
            break
for role in ("gf", "dna01", "dna02", "dnp09", "dng11", "mdn", "escw"):
    take([r for r, _ in sorted(strength_by_role[role].items(), key=lambda kv: (-kv[1], kv[0]))], 10)
take([r for r in ranked if sclass[r] == "ascending"], 24)
take([r for r in ranked if sclass[r] == "sensory"], 16)
take(ranked, MAX_PARTNERS - len(partners))
print("partner super_classes:", dict(Counter(sclass[r] for r in partners)))
sens = [r for r in partners if sclass[r] == "sensory"]
print("sensory partners:", dict(Counter(f"{ann.at[r,'class']}/{ann.at[r,'subclass']}/{ann.at[r,'type']}" for r in sens)))

members = sorted(core) + partners
idx = {b: i for i, b in enumerate(members)}
print(f"circuit members: {len(members)} ({len(core)} core + {len(partners)} partners)")

# --- pass 2: all published edges within the circuit --------------------------
inner = edges_all[edges_all.body_pre.isin(idx) & edges_all.body_post.isin(idx)]
edges, raw_counts, nt_missing = [], [], 0
for pre, post, w in inner.itertuples(index=False):
    sign = NT_SIGN.get(str(nt.get(pre, "")).lower())
    if sign is None:
        sign, nt_missing = 1.0, nt_missing + 1
    edges.append([idx[pre], idx[post], round(float(w) * sign, 1)])
print(f"circuit edges: {len(edges):,} (unknown transmitter on {nt_missing})")

# --- display transform: fit brain somata into [-10, 10]; left = negative x ----
def loc(b):
    v = ann.at[b, "somaLocation"]
    return None if v is None or (isinstance(v, float) and np.isnan(v)) else np.asarray(v, dtype=float)
brain = ann[ann.superclass.isin(BRAIN_SOMA)]
P = np.stack([v for v in brain.somaLocation if v is not None and not (isinstance(v, float))])
lo, hi = np.percentile(P, 0.5, axis=0), np.percentile(P, 99.5, axis=0)   # ignore stray somata
c = (lo + hi) / 2
scale = 20.0 / (hi - lo).max()
def norm(p):
    # MaleCNS voxel space: +x is the animal's left; the app draws left at -x, dorsal up, anterior toward the viewer
    return [round(float(-(p[0] - c[0]) * scale), 3), round(float(-(p[1] - c[1]) * scale), 3), round(float(-(p[2] - c[2]) * scale), 3)]
def inbox(p):
    return bool(np.all(p >= lo - (hi - lo) * 0.05) and np.all(p <= hi + (hi - lo) * 0.05))

pos = {}
for b in members:
    p = loc(b)
    if p is not None and inbox(p):
        pos[b] = p
# neurons with no soma in the brain: weight-averaged soma position of their circuit partners
for b in members:
    if b in pos:
        continue
    nb = pd.concat([inner[inner.body_pre == b][["body_post", "weight"]].rename(columns={"body_post": "o"}),
                    inner[inner.body_post == b][["body_pre", "weight"]].rename(columns={"body_pre": "o"})])
    nb = nb[nb.o.isin(pos)]
    pos[b] = (np.average(np.stack([pos[o] for o in nb.o]), axis=0, weights=nb.weight) if len(nb) else c)
print(f"positions: {sum(loc(b) is not None and inbox(loc(b)) for b in members)} from somata, "
      f"{sum(not (loc(b) is not None and inbox(loc(b))) for b in members)} placed at partner centroid")

def side_of(b):
    s = ann.at[b, "somaSide"]
    if s not in ("L", "R"):
        s = ann.at[b, "rootSide"]
    return {"L": "left", "R": "right"}.get(s, "center")

neurons = []
for b in members:
    neurons.append({"id": str(b), "type": ann.at[b, "type"] if b in core else sclass[b],
                    "role": core.get(b, "other"), "side": side_of(b), "pos": norm(pos[b]),
                    "cellType": None if pd.isna(ann.at[b, "type"]) else str(ann.at[b, "type"]),
                    "nt": None if pd.isna(nt.get(b, np.nan)) else str(nt.get(b))})
with open(OUT / "circuit.json", "w") as f:
    json.dump({"neurons": neurons, "edges": edges, "model": MODEL,
               "source": f"MaleCNS v1.0 flat connectome (weight>={MIN_WEIGHT}, signed by consensus_nt), CC BY 4.0",
               "files": {k: BASE + v for k, v in FILES.items()}}, f)
print(f"circuit.json: {len(neurons)} neurons, {len(edges)} edges")

# --- brain point cloud --------------------------------------------------------
sc_idx = {s: i for i, s in enumerate(SUPER_CLASSES)}
cloud = brain[[v is not None and not isinstance(v, float) for v in brain.somaLocation]].sort_index()
cloud = cloud[[inbox(np.asarray(v, dtype=float)) for v in cloud.somaLocation]]
stride = max(1, len(cloud) // MAX_POINTS)
points = [norm(np.asarray(v, dtype=float)) + [sc_idx[SUPER[s]]] for v, s in zip(cloud.somaLocation.iloc[::stride], cloud.superclass.iloc[::stride])]
with open(OUT / "brain_points.json", "w") as f:
    json.dump({"classes": SUPER_CLASSES, "points": points,
               "source": "MaleCNS v1.0 body annotations (somaLocation), CC BY 4.0"}, f)
print(f"brain_points.json: {len(points)} points")

# --- report: in-circuit drive onto each command population --------------------
E = np.array(edges)
role = [n["role"] for n in neurons]
print("in-circuit input (signed synapses) per population:")
for r in ("gf", "dna01", "dna02", "dnp09", "dng11", "mdn", "escw", "lc4", "lplc2"):
    tgt = [i for i, x in enumerate(role) if x == r]
    m = np.isin(E[:, 1], tgt)
    exc, inh = E[m & (E[:, 2] > 0), 2].sum(), E[m & (E[:, 2] < 0), 2].sum()
    loom = [i for i, x in enumerate(role) if x in ("lc4", "lplc2")]
    from_loom = E[m & np.isin(E[:, 0], loom), 2].sum()
    print(f"  {r:6s} n={len(tgt):3d}  exc {exc:9.0f}  inh {inh:9.0f}  from LC4/LPLC2 {from_loom:8.0f}")
sidx = [i for i, n in enumerate(neurons) if n["type"] == "sensory"]
gfi = [i for i, x in enumerate(role) if x == "gf"]
m = np.isin(E[:, 0], sidx) & np.isin(E[:, 1], gfi)
print(f"sensory -> GF: {len(set(E[m, 0]))} of {len(sidx)} sensory partners, {E[m, 2].sum():.1f} signed synapses")
