# FieldBee Parity Gap Analysis (iOS Guidance App)

## Current Architecture (Observed)
- **SwiftUI + SceneKit core**: `AgGuidanceDemo` drives the main UI overlay on top of a SceneKit guidance scene, with `AgGuidanceState` owning view state, simulator state, and guidance state. This is the primary architecture for the app’s runtime. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L1-L220】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L1-L220】
- **Guidance domain**: Guidance is abstracted via a `GuidanceEngine` protocol and implemented with a **straight AB line** engine (`StraightABGuidance`). Curved AB and headland engines are not implemented. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/GuidanceEngine.swift†L1-L70】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/ABLine.swift†L1-L220】
- **Local data persistence**: SQLite-backed `DatabaseManager` with ISOXML-style entities (customers, farmers, farms, partfields, tasks, devices, products, coverage/task logs). A `FieldTaskManager` wraps database operations for SwiftUI. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/DatabaseManager.swift†L1-L200】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L1-L220】
- **ISOXML-aligned data models**: `ISOXMLModels.swift` defines entities and field boundaries (polygon points + area calculation), but no explicit ISOXML import/export implementation is present. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/ISOXMLModels.swift†L1-L260】

## Current UI Flows (Observed)
- **Main guidance screen**: `AgGuidanceDemo` is the main view, with top controls (view mode, heading mode, background), cross‑track indicator, coordinate & GNSS status panel, simulator controls, action buttons (Tasks, Field boundary demo, Set AB, Clear, Settings), and manual steering controls. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L1-L380】
- **Settings**: `AgGuidanceSettings` provides configuration for machine/implement profiles and position source (simulator vs GNSS) including device selection. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceSettings.swift†L1-L220】
- **Field & task management**: `FieldTaskView` lists farms, fields, and tasks with CRUD actions and task lifecycle controls (start/pause/complete). It shows an active task summary. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/FieldTaskView.swift†L1-L220】
- **Field boundary**: A demo boundary button populates a static square boundary in local coordinates; this is not a full boundary‑capture flow. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L318-L366】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L613-L666】

## Current Data Handling (Observed)
- **SQLite schema**: Tables cover ISOXML‑style entities, tasks, coverage grid cells, and task logs. Coverage/task log data is stored but not shown tied into a complete “job/task” workflow beyond the Field/Task screen. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/DatabaseManager.swift†L1-L200】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L300-L360】
- **Boundary storage**: Field boundary polygons are stored as JSON in `partfields.boundary_json`; area is computed with the shoelace formula on models. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/DatabaseManager.swift†L457-L577】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/ISOXMLModels.swift†L200-L260】
- **Position logging/coverage**: The `FieldTaskManager` provides APIs to log positions and coverage cells. These are not currently wired into the guidance scene or UI beyond listing counts. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L300-L360】

---

## FieldBee Feature Comparison & Prioritized Gap List

### P0 – Required for FieldBee‑level Guidance
1. **Curved AB guidance**: Only straight AB exists via `StraightABGuidance`; no curved guidance engine or UI flow. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/GuidanceEngine.swift†L1-L70】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/ABLine.swift†L1-L220】
2. **Headland guidance and management**: No headland model, UI, or guidance calculations are present. Guidance flows are limited to AB lines. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/GuidanceEngine.swift†L1-L70】
3. **Field boundary capture workflow**: Current “Field” button creates a demo square boundary; no actual boundary recording from GNSS or track logging. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L318-L366】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L613-L666】

### P1 – Data & ISOXML Parity Gaps
4. **ISOXML import/export**: The schema is ISOXML‑inspired, but there is no parsing/export pipeline or ISOXML file I/O. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/ISOXMLModels.swift†L1-L260】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/DatabaseManager.swift†L1-L200】
5. **Task ↔ guidance coupling**: Tasks exist in the database and UI, but there is no explicit linkage between guidance state (AB lines, coverage, steering) and active task persistence. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L1-L220】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L300-L360】

### P2 – UX/Workflow Parity Gaps
6. **Unified operator workflow**: Guidance, field boundary, and task management are split across sheets and demo actions, rather than a single guided workflow typical of FieldBee. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L318-L366】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/FieldTaskView.swift†L1-L220】
7. **Task‑centric coverage visualization**: Coverage data exists in storage, but UI does not render coverage overlays per active task or persist coverage state back into job/task summaries. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L300-L360】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L1-L220】

---

## Architectural Risks
1. **Guidance extensibility risk**: The guidance engine is currently straight‑line only. Without a strategy for curved AB and headlands, guidance features will diverge quickly from FieldBee. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/GuidanceEngine.swift†L1-L70】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Guidance/ABLine.swift†L1-L220】
2. **Boundary capture/validation risk**: Boundary is a demo square and not derived from GNSS or operator capture. This blocks realistic task setup and field modeling. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L613-L666】
3. **ISOXML interoperability risk**: The data model is ISOXML‑shaped but does not read/write ISOXML files. This makes external interoperability and task import/export impossible. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/ISOXMLModels.swift†L1-L260】
4. **State synchronization risk**: Guidance state (AB lines, coverage, steering mode) is largely in‑memory and not persisted or aligned with tasks; this risks data loss and workflow mismatch. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceState.swift†L1-L220】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/Database/FieldTaskManager.swift†L300-L360】
5. **UI fragmentation risk**: Core workflows are split across multiple sheets with demo‑only actions. This complicates operator flow and makes it harder to mirror FieldBee’s guided UX. 【F:GoogleMaps3DDemo/GoogleMaps3DDemo/AgGuidanceDemo.swift†L318-L366】【F:GoogleMaps3DDemo/GoogleMaps3DDemo/FieldTaskView.swift†L1-L220】
