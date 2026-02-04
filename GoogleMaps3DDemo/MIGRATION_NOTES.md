# Migration Notes (Guidance + ISOXML Persistence)

## Summary

This release hardens the iOS guidance demo by integrating the SceneKit guidance flow with the ISOXML-aligned SQLite persistence layer. It also switches all coordinate conversions to WGS84 formulas.

## Data & Behavioral Changes

1. **Guidance persistence linkage**
   - Newly created AB lines are saved as `GLN` ISOXML guidance lines and linked to the active task.
   - Active tasks now restore guidance lines on load. If a task has no guidance link, the latest guidance line for the selected partfield is used.

2. **Coverage + task logging**
   - Coverage cells are written in batches to SQLite to support large datasets.
   - Position logs are throttled (1 Hz) and include work-point metadata for ISOXML export.

3. **WGS84 conversions**
   - All local↔WGS84 conversions now use WGS84 ellipsoid equations (used for AB guidance, simulator motion, and boundary area computation).

## Migration Steps

- **No schema migration required**: The existing SQLite schema already contains `guidance_line_id`/`headland_id` fields on tasks.
- **Existing tasks without guidance lines**:
  - Open the field in the app and set a new AB line to persist a `GLN` record.
  - Alternatively, link an existing guidance line to the active task from the field/task management view (future UI improvement).

## Validation Checklist

- Verify guidance lines load after app relaunch for the active task.
- Confirm boundary areas remain stable (WGS84 conversion change).
- Confirm coverage totals are stable when reloading a task with large coverage grids.
