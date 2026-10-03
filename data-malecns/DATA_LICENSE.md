# Data license (this directory)

Everything here is derived from the **MaleCNS v1.0** public connectome
(https://male-cns.janelia.org/download/) and is licensed under
**[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)** — share and adapt,
including commercially, with attribution.

Attribute the MaleCNS collaboration: FlyEM at HHMI Janelia, University of
Cambridge, MRC Laboratory of Molecular Biology, and Google Research.

No file in this directory is derived from FlyWire. An app bundle built with
`./package.sh --malecns` contains only these files and carries no
non-commercial restriction. (`../data/` holds the original FlyWire-derived
extract, CC BY-NC 4.0 — see `../data/DATA_LICENSE.md`.)

| file | contents |
|---|---|
| `circuit.json` | 665-neuron escape/steering brain circuit, 23,795 signed edges, fitted model parameters — see `PROVENANCE.md` |
| `brain_points.json` | 24,843 soma positions for the brain window |
| `locomotor_circuit.json`, `locomotor_report.json`, `LOCOMOTOR_PROVENANCE.md` | the leg circuit, copied unchanged from `../data/` (already MaleCNS, CC BY 4.0) |
