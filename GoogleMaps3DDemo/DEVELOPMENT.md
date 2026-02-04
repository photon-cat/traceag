# AgGuidance Development Documentation

## Project Overview

Agricultural guidance application built on iOS with SceneKit for visualization. Provides AB line guidance, coverage tracking, field management, and ISOXML-aligned persistence using WGS84 coordinates.

## Architecture

```
GoogleMaps3DDemo/
├── AgGuidanceDemo.swift      # Main SwiftUI view
├── AgGuidanceState.swift     # App state management + persistence bridge
├── AgGuidanceScene.swift     # SceneKit 3D rendering
├── AgGuidanceSettings.swift  # Settings UI
├── Guidance/
│   ├── GuidanceEngine.swift  # Guidance protocols & types
│   ├── ABLine.swift          # Straight AB line guidance
│   ├── PositionSource.swift  # Position input abstraction
│   └── WGS84Converter.swift  # WGS84 tangent-plane conversion
├── Database/                 # SQLite ISOXML-aligned persistence
│   ├── DatabaseManager.swift
│   ├── FieldTaskManager.swift
│   └── ISOXMLModels.swift
└── Info.plist
```

## Current Features

- [x] Straight AB line guidance with A/B point setting
- [x] ISOXML-aligned persistence for fields, tasks, guidance lines, and coverage
- [x] WGS84 coordinate conversion for guidance + storage parity
- [x] Infinite tile streaming world
- [x] Coverage tracking visualization (batched persistence)
- [x] Cross-track error indicator
- [x] 3D perspective and 2D top-down views
- [x] Auto-follow and manual steering modes
- [x] Configurable line spacing, implement width, heading
- [x] Simulator position source with configurable speed/location
- [x] Real device GNSS position source

## Roadmap

### Phase 1: Core Guidance (Current)
- [x] Straight AB lines
- [ ] Curved AB lines
- [ ] Headland management
- [ ] Boundary definition

### Phase 2: Data Persistence
- [x] SQLite ISOXML-aligned persistence
- [x] Field definitions with boundaries
- [x] Guidance line persistence + task linkage
- [ ] Equipment profiles
- [ ] Chemical/product records
- [ ] Application records

### Phase 3: Advanced Features
- [ ] Section control support
- [ ] Rate control integration
- [ ] Job/task management
- [ ] Export to common formats (shapefile, KML)
- [ ] Cloud sync (optional)

### Phase 4: External Integration
- [ ] NMEA GPS receiver support
- [ ] RTK correction sources
- [ ] Implement controller communication
- [ ] Weather integration

---

## Pre-Push Hooks

### Setup

Install the git hooks by running:

```bash
./scripts/install-hooks.sh
```

### Hook Configuration

The pre-push hook runs the following checks:

1. **Swift Format Check** - Ensures consistent code style
2. **Build Check** - Verifies the project compiles
3. **Unit Tests** - Runs the test suite
4. **Type Check** - Swift compiler type checking

### Hook Script Location

```
.githooks/pre-push
```

### Bypassing Hooks (Emergency Only)

```bash
git push --no-verify
```

### CI/CD Integration

GitHub Actions workflow mirrors the pre-push checks:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Build
        run: |
          xcodebuild -scheme GoogleMaps3DDemo \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            build

      - name: Test
        run: |
          xcodebuild -scheme GoogleMaps3DDemo \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
            test
```

---

## Database Schema

### Overview

Using SwiftData for local persistence with optional CloudKit sync.

### Models

#### Field

```swift
@Model
class Field {
    @Attribute(.unique) var id: UUID
    var name: String
    var boundaryCoordinates: [Coordinate]  // WGS84 polygon
    var areaHectares: Double
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var jobs: [Job]

    @Relationship
    var farm: Farm?
}
```

#### Farm

```swift
@Model
class Farm {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String?

    @Relationship(deleteRule: .cascade)
    var fields: [Field]
}
```

#### Equipment

```swift
@Model
class Equipment {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: EquipmentType  // sprayer, spreader, planter, etc.
    var implementWidth: Double  // meters
    var numberOfSections: Int
    var sectionWidths: [Double]  // meters per section

    @Relationship(deleteRule: .cascade)
    var jobs: [Job]
}

enum EquipmentType: String, Codable {
    case sprayer
    case spreader
    case planter
    case seeder
    case cultivator
    case other
}
```

#### Chemical/Product

```swift
@Model
class Product {
    @Attribute(.unique) var id: UUID
    var name: String
    var manufacturer: String?
    var type: ProductType
    var unit: ProductUnit
    var defaultRate: Double
    var minRate: Double?
    var maxRate: Double?
    var epaNumber: String?  // EPA registration number
    var activeIngredients: [String]

    @Relationship(deleteRule: .cascade)
    var applications: [Application]
}

enum ProductType: String, Codable {
    case herbicide
    case insecticide
    case fungicide
    case fertilizer
    case seedTreatment
    case adjuvant
    case other
}

enum ProductUnit: String, Codable {
    case litersPerHectare = "L/ha"
    case kilogramsPerHectare = "kg/ha"
    case gallonsPerAcre = "gal/ac"
    case poundsPerAcre = "lb/ac"
    case unitsPerAcre = "units/ac"
}
```

#### Job

```swift
@Model
class Job {
    @Attribute(.unique) var id: UUID
    var name: String
    var status: JobStatus
    var startedAt: Date?
    var completedAt: Date?
    var notes: String?

    // Guidance configuration
    var guidanceType: GuidanceType
    var abLineA: Coordinate?
    var abLineB: Coordinate?
    var lineSpacing: Double

    // Coverage data
    var coveredAreaHectares: Double
    var coveragePercentage: Double

    @Relationship
    var field: Field?

    @Relationship
    var equipment: Equipment?

    @Relationship(deleteRule: .cascade)
    var applications: [Application]

    @Relationship(deleteRule: .cascade)
    var coverageRecords: [CoverageRecord]
}

enum JobStatus: String, Codable {
    case planned
    case inProgress
    case paused
    case completed
    case cancelled
}

enum GuidanceType: String, Codable {
    case straightAB
    case curvedAB
    case adaptive
    case none
}
```

#### Application

```swift
@Model
class Application {
    @Attribute(.unique) var id: UUID
    var appliedRate: Double
    var targetRate: Double
    var totalVolume: Double
    var appliedAt: Date

    @Relationship
    var product: Product?

    @Relationship
    var job: Job?
}
```

#### CoverageRecord

```swift
@Model
class CoverageRecord {
    var id: UUID
    var timestamp: Date
    var coordinate: Coordinate
    var heading: Double
    var speed: Double
    var sectionsActive: [Bool]  // Which sections were on

    @Relationship
    var job: Job?
}
```

#### Coordinate (Value Type)

```swift
struct Coordinate: Codable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?

    init(latitude: Double, longitude: Double, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    init(from clCoordinate: CLLocationCoordinate2D) {
        self.latitude = clCoordinate.latitude
        self.longitude = clCoordinate.longitude
        self.altitude = nil
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

### Repository Pattern

```swift
protocol FieldRepository {
    func getAll() async throws -> [Field]
    func getById(_ id: UUID) async throws -> Field?
    func save(_ field: Field) async throws
    func delete(_ field: Field) async throws
}

protocol JobRepository {
    func getAll() async throws -> [Job]
    func getActive() async throws -> [Job]
    func getForField(_ fieldId: UUID) async throws -> [Job]
    func save(_ job: Job) async throws
    func delete(_ job: Job) async throws
}

protocol ProductRepository {
    func getAll() async throws -> [Product]
    func search(query: String) async throws -> [Product]
    func save(_ product: Product) async throws
    func delete(_ product: Product) async throws
}

protocol EquipmentRepository {
    func getAll() async throws -> [Equipment]
    func save(_ equipment: Equipment) async throws
    func delete(_ equipment: Equipment) async throws
}
```

### Database Configuration

```swift
import SwiftData

@MainActor
class DatabaseManager {
    static let shared = DatabaseManager()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            Farm.self,
            Field.self,
            Equipment.self,
            Product.self,
            Job.self,
            Application.self,
            CoverageRecord.self
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Set to .automatic for CloudKit sync
        )

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var mainContext: ModelContext {
        container.mainContext
    }
}
```

---

## Testing Strategy

### Unit Tests

- Guidance calculations (cross-track error, line generation)
- Coordinate conversions
- Coverage tracking logic
- Repository operations

### Integration Tests

- Database CRUD operations
- Position source switching
- Scene rendering

### UI Tests

- AB line workflow (Set A -> Set B -> guidance active)
- Settings changes persist
- Coverage displays correctly

---

## Contributing

1. Create a feature branch from `main`
2. Ensure pre-push hooks pass
3. Write tests for new functionality
4. Submit PR with description of changes
