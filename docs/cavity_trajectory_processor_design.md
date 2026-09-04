# Cavity trajectory selection downstream of the latent cell model

## Purpose

`selectCavityTrajectory` selects the biological cell that occupies an
experimental role in a microfluidic cavity.  It runs after
`cellLatentModel`: it consumes stable TrackIDs, parent/child relations and
their mask provider, rather than tracking frame-local contours again.

The latent result and the cavity result answer different questions:

- the latent cell model asks which observations belong to the same
  biological cell and which cells are related;
- the cavity processor asks which biological cell currently occupies the
  role of resident mother or daughter-cavity tip cell.

The processor never rewrites latent TrackIDs or parentage.

## Identity levels

The version-1 output keeps four concepts separate:

| Field | Meaning |
|---|---|
| `TargetTrackID` | Immutable latent TrackID selected on a frame |
| `SubjectID` | Reconstructed biological subject; equal to TrackID in v1 |
| `OccupancyEpisodeID` | One uninterrupted occupation by one subject |
| `TrajectoryID` | Experimental-role path, which may span lineage handovers |

Future fragment stitching may map several TrackIDs to one `SubjectID`, but
such a correction must remain explicit, scored and reversible.

## Modes

### `mother_resident`

The decoder favours a persistent cell near the configured cavity anchor.
Visible children of the selected mother may be exposed separately as a
companion bud. A switch to another TrackID starts a new occupancy episode and
is reported as an unrelated replacement; parentage alone never causes the
resident mother to change.

### `daughter_tip`

The decoder favours the cell furthest along the configured cavity axis. A
parent-to-child switch is allowed only after the child's lineage event plus a
minimum age and a configurable improvement in tip position. Bud birth is not
treated as cytokinesis: the event is a candidate handover, not proof that the
child has detached or replaced the parent.

## Output contract

The processor creates a temporal `dataseries` whose frame table contains:

- frame, trajectory, occupancy episode, TrackID and subject ID;
- companion-bud TrackID;
- selected mask label and role;
- typed transition, path-margin confidence, abstention and QC flags.

The complete result also contains `events` and `lifespans` tables and is
written as a JSON audit artifact. Three compatibility channels are projected
from the selected object family:

- `<base>_cell`: selected biological cell;
- `<base>_bud`: selected cell's companion bud;
- `<base>_object`: union of cell and companion bud.

These raster projections are downstream views. The tables remain canonical.

## Solver

Version 1 uses a global dynamic program over stable TrackIDs plus a NULL
state. Emissions describe cavity position and area. Transitions distinguish
continuation, gaps, parent-to-child handover and unrelated replacement.
Short internal gaps of one TrackID can remain attached to the same subject.

Confidence is currently an uncalibrated path-margin score. It must not be
interpreted as a biological probability. MYO1/HTB2-derived budding, nuclear
division and cytokinesis probabilities will later enter only as calibrated
soft evidence with an abstention path; those event types remain distinct.

## Visualization

`cavityTrajectoryView.plotTrajectory` inspects one role trajectory and can
focus on a TrackID selected in Score. `cavityTrajectoryView.plotLifespanPool`
pools occupancy lifespans from several ROI/dataseries inputs and aligns them
on episode start. `score_cavityTrajectoryDialog` is the GUI-neutral bridge
that Score can call after the user selects a cell object.

The existing crossing-free Score lineage layout remains reusable. A later UI
change should pass the selected TrackID and active ROI to the bridge instead
of adding trajectory business logic to `score.mlapp`.

## Development and evaluation

The cavity-mother ROI 102/115/146 remain locked regression tests. Development
uses the declared training/validation cavity split and a new reviewed
daughter-cavity target dataset. New scientific datasets, predictions and
rendered panels must be materialized in versioned directories below
`C:\Users\Gilles\SynologyDrive\Data\cell_latent_model`, with manifests and
source/output SHA-256 fingerprints.

Minimum future evaluation includes target-frame accuracy, handover timing,
false switches, unrelated-replacement detection, abstention/calibration,
false fragment merges and lifespan censoring accuracy.
