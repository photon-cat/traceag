# ISOXML Local Data Model & Storage (Offline-First)

This document proposes an ISOXML-aligned local schema, storage choice, and import/export + migration strategy for the Guidance app.

## Goals
- **ISOXML alignment**: Model the core ISOXML entities (fields, boundaries, guidance lines, headlands, tasks, implements).
- **Offline-first**: Fast local reads/writes with deterministic IDs and incremental sync/export.
- **Extensible**: Allow future ISOXML features (DDI values, product sets, prescriptions, logs).

---

## 1) ISOXML-Aligned Schema

### 1.1 Core Entities (Table/Record Overview)
| Entity | ISOXML Mapping | Purpose | Key Fields |
| --- | --- | --- | --- |
| Customer | CTR | Account/tenant | id, name, created_at |
| Farmer | FRM | Operator/owner | id, customer_id, name, contact |
| Farm | FAR | Farm grouping | id, farmer_id, name |
| Partfield | PFD | Field (area + boundary) | id, farm_id, name, boundary_id |
| FieldBoundary | PFD/BND | Boundary polygon | id, partfield_id, points_geojson, area_m2 |
| GuidanceLine | GLN | AB line or curved path | id, partfield_id, type, points_geojson, spacing_m |
| Headland | HLD | Headland boundary/offset | id, partfield_id, boundary_geojson, offset_m |
| Task | TSK | Operation per field | id, partfield_id, type, status, start/end |
| Implement | DVC | Equipment profile | id, name, type, work_width_m |
| TaskLog | TLG | Logged positions & values | id, task_id, ts, lat, lon, speed, heading |
| CoverageCell | COV | Coverage grid | id, task_id, grid_key, area_m2 |

**Notes**
- **GuidanceLine** maps to ISOXML guidance data and should support straight AB (`type=straight_ab`) and curved AB (`type=curved_ab`).
- **Headland** stores explicit boundary geometry and offset metadata for headland guidance.
- **Implement** models devices and implements using ISOXML device/implement profiles.

### 1.2 Detailed Field Definitions

#### Partfield (PFD)
- `id` (string): ISOXML IdTable ID (e.g., `PFD1`).
- `farm_id` (string): ISOFarm reference.
- `name` (string)
- `season` (string?)
- `crop_type` (string?)
- `boundary_id` (string?): Foreign key to FieldBoundary.
- `notes` (string?)
- `created_at`, `updated_at` (datetime)

#### FieldBoundary (Boundary Geometry)
- `id` (string): e.g., `BND1`
- `partfield_id` (string): FK to Partfield.
- `points_geojson` (text): Polygon or MultiPolygon, WGS84.
- `area_m2` (double)
- `source` (enum): `recorded`, `imported`, `edited`
- `created_at`, `updated_at`

#### GuidanceLine (AB/Curved)
- `id` (string): e.g., `GLN1`
- `partfield_id` (string)
- `type` (enum): `straight_ab`, `curved_ab`
- `points_geojson` (text): LineString with at least two points.
- `heading_deg` (double?): Optional for straight AB.
- `spacing_m` (double?): Swath spacing.
- `active` (bool)
- `created_at`, `updated_at`

#### Headland
- `id` (string)
- `partfield_id` (string)
- `boundary_geojson` (text): Polygon for headland path.
- `offset_m` (double): Offset distance from boundary.
- `direction` (enum): `inward`, `outward`
- `created_at`, `updated_at`

#### Task
- `id` (string): e.g., `TSK1`
- `partfield_id` (string)
- `task_type` (enum): `planting`, `spraying`, etc.
- `status` (enum): `pending`, `in_progress`, `paused`, `completed`, `cancelled`
- `device_id` (string?): FK to Implement/Device.
- `product_id` (string?): ISOXML product link.
- `guidance_line_id` (string?): FK to GuidanceLine (optional active line).
- `headland_id` (string?): FK to Headland.
- `start_at`, `end_at`, `created_at`, `updated_at`

#### Implement (Device)
- `id` (string)
- `name` (string)
- `device_type` (enum): `tractor`, `sprayer`, `seeder`, `planter`, `other`
- `work_width_m` (double?)
- `wheelbase_m` (double?)
- `antenna_offset` (json): { lateral, forward, height }
- `created_at`, `updated_at`

#### TaskLog
- `id` (int)
- `task_id` (string)
- `timestamp` (datetime)
- `lat`, `lon` (double)
- `heading_deg` (double?)
- `speed_mps` (double?)
- `values_json` (text?)

#### CoverageCell
- `id` (int)
- `task_id` (string)
- `grid_key` (string): e.g., geohash or `x:y` tile key
- `area_m2` (double)
- `created_at`

---

## 2) Local Storage Choice & Validation

### Recommended: SQLite (current code already uses it)
**Why SQLite**
- **Offline-first**: Durable local store with transaction support.
- **Scale**: Handles large logs/coverage faster than Core Data for append-heavy writes.
- **Cross-platform**: Easier to port to Android/desktop for ISOXML parity.

**When Core Data could be used**
- If the app needs deep SwiftUI integration with automatic object graph behavior.
- If the store must be cloud-synced with iCloud/CloudKit directly.

**Validation Strategy**
- **Schema constraints**: Use foreign keys for Partfield → Boundary, Task → GuidanceLine/Headland.
- **Geometry validation**: Validate polygon closure and minimum points before persisting.
- **IdTable parity**: Maintain ISOXML ID prefixes (PFD/TSK/DVC/GLN/HLD) for export.

---

## 3) Import/Export Behavior (ISOXML)

### Import
1. **Parse TaskData.xml** (ISOXML) into staging models.
2. **IdTable resolution**: Map ISOXML IDs to local records (preserve ISOXML IDs).
3. **Geometry conversion**: Convert ISOXML boundary/AB line data to GeoJSON/Polyline.
4. **Conflict strategy**:
   - If local record exists → update via `updated_at` with merge rules.
   - If not → insert with `source=imported`.

### Export
1. **Select scope**: by farm/field/task range.
2. **Generate IdTable + TaskData.xml** using stored ISOXML IDs.
3. **Serialize geometry**: Convert GeoJSON back into ISOXML `PFD`/`LSG`/`GLN`/`HLD` structures.
4. **Bundle logs**: Export task logs and coverage grids as optional ISOXML extensions.

---

## 4) Data Migration Strategy

### Versioning
- **Schema versioning**: Store `schema_version` in a dedicated metadata table.
- **Migrators**: Incremental migrations (v1 → v2, v2 → v3) with reversible steps where possible.

### Migration Plan
1. **Additive changes first**: New tables/columns (`guidance_lines`, `headlands`).
2. **Backfill**: Populate `guidance_line_id` for active tasks based on current AB line state.
3. **Data cleanup**: Validate boundary polygons and recompute `area_m2`.
4. **Export compatibility**: Ensure all existing entities have ISOXML-compliant IDs.

### Example Migration Steps
- **v1**: Add `guidance_lines` and `headlands` tables.
- **v2**: Add `guidance_line_id` and `headland_id` to `tasks`.
- **v3**: Add `boundary_id` to `partfields` and migrate existing JSON boundaries.

---

## 5) Implementation Notes (SQLite)

### Suggested Table Additions
```sql
CREATE TABLE guidance_lines (
  id TEXT PRIMARY KEY,
  partfield_id TEXT NOT NULL REFERENCES partfields(id),
  type TEXT NOT NULL,
  points_geojson TEXT NOT NULL,
  heading_deg REAL,
  spacing_m REAL,
  active INTEGER DEFAULT 0,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE TABLE headlands (
  id TEXT PRIMARY KEY,
  partfield_id TEXT NOT NULL REFERENCES partfields(id),
  boundary_geojson TEXT NOT NULL,
  offset_m REAL,
  direction TEXT,
  created_at DATETIME,
  updated_at DATETIME
);
```

### Suggested Indexes
```sql
CREATE INDEX idx_guidance_lines_partfield ON guidance_lines(partfield_id);
CREATE INDEX idx_headlands_partfield ON headlands(partfield_id);
CREATE INDEX idx_tasklog_task_timestamp ON task_logs(task_id, timestamp);
```

---

## 6) Validation Checklist
- [ ] Boundary polygons are closed and have ≥ 3 points.
- [ ] Guidance lines have at least two points.
- [ ] Headland offset is within a reasonable range.
- [ ] Task references are valid (partfield/device/line/headland).
- [ ] Exported ISOXML IDs match IdTable prefix rules.

---

## 7) Next Steps
1. Implement guidance line + headland tables in SQLite.
2. Add import/export layer (TaskData.xml parsing + serialization).
3. Add migration scaffolding in `DatabaseManager`.
4. Wire guidance state to active task + guidance line references.

