# DetecDiv cellular object model

Schema v1 separates three concerns that were previously mixed in
`cell_information`:

- ROI image channels remain the source of truth for mask pixels.
- `objects_<roi-id>.h5` stores compact object, track, state, family and
  parent/child references.
- `roi.display.objectDisplay` stores display presets only; it is not
  scientific data.

An instance refers to mask geometry with the stable tuple
`(family_id, frame, mask_label)`. A family owns its `mask_provider`, so two
families may use different indexed channels in the same ROI. Several families
may also share one provider, but their instances and genealogies remain
independent.

## HDF5 layout

The sidecar uses typed columnar datasets:

- `/instances/{object_id,family_id,frame,mask_label,track_id,state_id}`
- `/relations/{relation_id,family_id,parent_track_id,child_track_id,event_frame,type_id,confidence}`
- `/metadata_json` for small family/state/type/provenance tables

The columnar representation avoids copying masks and is directly readable
with `h5py`. See `python/detecdiv_cell_model.py`.

## Synchronization rules

Mask edits are reconciled with `cellModel.syncFrame`; unchanged labels retain
their object, track and state IDs. Explicit relabel operations use
`cellModel.relabelFrame` so an object's identity follows the pixels. Score
persists the model sidecar after editing but never writes model data into the
ROI image HDF5.

Genealogy is scoped by `family_id`. One parent may have several children, but
a child track may have only one parent within a family. Validation also
forbids one track from mapping to several mask labels in the same frame.

## Legacy migration

`roi.loadCellModel('MigrateLegacy',true)` creates an in-memory model from all
legacy lineage sources and indexed mask channels. Add
`'PersistMigration',true` to write the sidecar. Migration is explicit; merely
opening an old ROI does not change it.
