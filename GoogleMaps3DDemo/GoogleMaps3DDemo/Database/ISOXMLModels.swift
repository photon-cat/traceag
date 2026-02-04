// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreLocation

// MARK: - Entity Types

/// Entity types for the IdTable
enum EntityType: String, Codable {
    case customer = "CTR"
    case farmer = "FRM"
    case farm = "FAR"
    case partfield = "PFD"
    case task = "TSK"
    case device = "DVC"
    case product = "PDT"
    case guidanceLine = "GLN"
    case headland = "HDL"
}

// MARK: - Task Types

/// Types of agricultural tasks
enum TaskType: String, Codable, CaseIterable {
    case planting = "planting"
    case spraying = "spraying"
    case fertilizing = "fertilizing"
    case harvesting = "harvesting"
    case tillage = "tillage"
    case seeding = "seeding"
    case mowing = "mowing"
    case scouting = "scouting"
    case other = "other"

    var displayName: String {
        switch self {
        case .planting: return "Planting"
        case .spraying: return "Spraying"
        case .fertilizing: return "Fertilizing"
        case .harvesting: return "Harvesting"
        case .tillage: return "Tillage"
        case .seeding: return "Seeding"
        case .mowing: return "Mowing"
        case .scouting: return "Scouting"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .planting: return "leaf.fill"
        case .spraying: return "drop.fill"
        case .fertilizing: return "sparkles"
        case .harvesting: return "shippingbox.fill"
        case .tillage: return "tractor"
        case .seeding: return "circle.grid.3x3.fill"
        case .mowing: return "scissors"
        case .scouting: return "binoculars.fill"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Task Status

/// Status of a task
enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .inProgress: return "blue"
        case .paused: return "orange"
        case .completed: return "green"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Boundary Point

/// A single point in a field boundary polygon
struct BoundaryPoint: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

// MARK: - Guidance Geometry Points

/// A single point in a guidance line polyline
struct GuidancePoint: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

// MARK: - Guidance Line Types

enum GuidanceLineType: String, Codable, CaseIterable {
    case straightAB = "straight_ab"
    case curvedAB = "curved_ab"
}

// MARK: - ISO Guidance Line

struct ISOGuidanceLine: Identifiable, Codable, Equatable {
    let id: String
    let partfieldId: String
    var type: GuidanceLineType
    var points: [GuidancePoint]
    var spacingM: Double
    var headingDeg: Double?
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, partfieldId: String, type: GuidanceLineType, points: [GuidancePoint], spacingM: Double, headingDeg: Double? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.partfieldId = partfieldId
        self.type = type
        self.points = points
        self.spacingM = spacingM
        self.headingDeg = headingDeg
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISO Headland

struct ISOHeadland: Identifiable, Codable, Equatable {
    let id: String
    let partfieldId: String
    var boundary: [BoundaryPoint]
    var offsetM: Double
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, partfieldId: String, boundary: [BoundaryPoint], offsetM: Double, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.partfieldId = partfieldId
        self.boundary = boundary
        self.offsetM = offsetM
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISOCustomer

/// Internal account identifier (not exposed to farmer)
/// Used to track subscription/licensing info
struct ISOCustomer: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, name: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISOFarmer

/// Represents a farmer user who creates farms and fields
struct ISOFarmer: Identifiable, Codable, Equatable {
    let id: String
    let customerId: String  // References ISOCustomer - set automatically
    var firstName: String?
    var lastName: String
    var email: String?
    var phone: String?
    var createdAt: Date?
    var updatedAt: Date?

    var fullName: String {
        if let first = firstName {
            return "\(first) \(lastName)"
        }
        return lastName
    }

    init(id: String, customerId: String, firstName: String? = nil, lastName: String, email: String? = nil, phone: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.customerId = customerId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISOFarm

/// Represents a farm entity owned by a farmer
struct ISOFarm: Identifiable, Codable, Equatable {
    let id: String
    let farmerId: String  // References ISOFarmer
    var name: String
    var address: String?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, farmerId: String, name: String, address: String? = nil, notes: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.farmerId = farmerId
        self.name = name
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISOPartfield

/// Represents a field (partfield) with boundary polygon
/// Created at root level with ISOFarm reference
struct ISOPartfield: Identifiable, Codable, Equatable {
    let id: String          // e.g., "PFD1"
    let farmId: String      // References ISOFarm
    var name: String
    var areaM2: Double?     // Calculated area in square meters
    var season: String?     // e.g., "2025 Spring"
    var cropType: String?   // e.g., "Corn", "Wheat"
    var notes: String?
    var boundary: [BoundaryPoint]?  // Polygon boundary
    var createdAt: Date?
    var updatedAt: Date?

    /// Area in hectares
    var areaHectares: Double? {
        guard let area = areaM2 else { return nil }
        return area / 10000.0
    }

    /// Area in acres
    var areaAcres: Double? {
        guard let area = areaM2 else { return nil }
        return area / 4046.86
    }

    init(id: String, farmId: String, name: String, areaM2: Double? = nil, season: String? = nil, cropType: String? = nil, notes: String? = nil, boundary: [BoundaryPoint]? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.farmId = farmId
        self.name = name
        self.areaM2 = areaM2
        self.season = season
        self.cropType = cropType
        self.notes = notes
        self.boundary = boundary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Calculate area from boundary polygon using Shoelace formula
    mutating func calculateArea() {
        guard let points = boundary, points.count >= 3 else {
            areaM2 = nil
            return
        }

        // Convert to local meters (approximate)
        let centerLat = points.map { $0.latitude }.reduce(0, +) / Double(points.count)
        let meters = WGS84Converter.metersPerDegree(atLatitude: centerLat)

        // Convert to meters
        let metersPoints = points.map { p in
            (x: (p.longitude - points[0].longitude) * meters.lon,
             y: (p.latitude - points[0].latitude) * meters.lat)
        }

        // Shoelace formula for polygon area
        var sum = 0.0
        for i in 0..<metersPoints.count {
            let j = (i + 1) % metersPoints.count
            sum += metersPoints[i].x * metersPoints[j].y
            sum -= metersPoints[j].x * metersPoints[i].y
        }
        areaM2 = abs(sum) / 2.0
    }
}

// MARK: - ISOTask

/// Represents a task performed on a partfield
/// Each task has PartfieldIdRef linking to its field
struct ISOTask: Identifiable, Codable, Equatable {
    let id: String              // e.g., "TSK1"
    let partfieldId: String     // References ISOPartfield (PartfieldIdRef)
    var name: String
    var taskType: TaskType
    var status: TaskStatus
    var deviceId: String?       // References Device/Implement
    var productId: String?      // References Product (seed, fertilizer, etc.)
    var guidanceLineId: String?
    var headlandId: String?
    var notes: String?
    var startedAt: Date?
    var completedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, partfieldId: String, name: String, taskType: TaskType, status: TaskStatus = .pending, deviceId: String? = nil, productId: String? = nil, guidanceLineId: String? = nil, headlandId: String? = nil, notes: String? = nil, startedAt: Date? = nil, completedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.partfieldId = partfieldId
        self.name = name
        self.taskType = taskType
        self.status = status
        self.deviceId = deviceId
        self.productId = productId
        self.guidanceLineId = guidanceLineId
        self.headlandId = headlandId
        self.notes = notes
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ISODevice

/// Represents a device (tractor, implement, etc.)
struct ISODevice: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var deviceType: DeviceType
    var config: DeviceConfig?
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, name: String, deviceType: DeviceType, config: DeviceConfig? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.config = config
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum DeviceType: String, Codable, CaseIterable {
    case tractor = "tractor"
    case combine = "combine"
    case sprayer = "sprayer"
    case seeder = "seeder"
    case planter = "planter"
    case tillageEquipment = "tillage"
    case other = "other"

    var displayName: String {
        switch self {
        case .tractor: return "Tractor"
        case .combine: return "Combine"
        case .sprayer: return "Sprayer"
        case .seeder: return "Seeder"
        case .planter: return "Planter"
        case .tillageEquipment: return "Tillage Equipment"
        case .other: return "Other"
        }
    }
}

/// Antenna offset configuration
struct AntennaOffset: Codable, Equatable {
    var lateral: Double
    var forward: Double
    var height: Double

    init(lateral: Double = 0, forward: Double = 0, height: Double = 0) {
        self.lateral = lateral
        self.forward = forward
        self.height = height
    }
}

/// Device configuration (implements MachineProfile/ImplementProfile)
struct DeviceConfig: Codable, Equatable {
    var wheelbase: Double?
    var workWidth: Double?
    var antennaOffset: AntennaOffset?

    init(wheelbase: Double? = nil, workWidth: Double? = nil, antennaOffset: AntennaOffset? = nil) {
        self.wheelbase = wheelbase
        self.workWidth = workWidth
        self.antennaOffset = antennaOffset
    }
}

// MARK: - ISOProduct

/// Represents a product (seed, fertilizer, chemical, etc.)
struct ISOProduct: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var productType: ProductType
    var unit: String?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?

    init(id: String, name: String, productType: ProductType, unit: String? = nil, notes: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.productType = productType
        self.unit = unit
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ProductType: String, Codable, CaseIterable {
    case seed = "seed"
    case fertilizer = "fertilizer"
    case herbicide = "herbicide"
    case pesticide = "pesticide"
    case fungicide = "fungicide"
    case other = "other"

    var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .fertilizer: return "Fertilizer"
        case .herbicide: return "Herbicide"
        case .pesticide: return "Pesticide"
        case .fungicide: return "Fungicide"
        case .other: return "Other"
        }
    }
}

// MARK: - TaskLog Entry

/// A single log entry for a task (position + data)
struct TaskLogEntry: Identifiable, Codable {
    let id: Int
    let taskId: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    var heading: Double?
    var speed: Double?
    var data: [String: String]?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - IdTable Entry

/// Entry in the IdTable for entity resolution
struct IdTableEntry: Identifiable, Codable {
    let id: String
    let entityType: EntityType
    let createdAt: Date?

    init(id: String, entityType: EntityType, createdAt: Date? = nil) {
        self.id = id
        self.entityType = entityType
        self.createdAt = createdAt
    }
}
