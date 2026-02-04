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
import Combine
import CoreLocation

/// Observable manager for field and task operations
/// Provides a reactive interface to the database for SwiftUI views
final class FieldTaskManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FieldTaskManager()

    // MARK: - Published Properties

    @Published private(set) var currentCustomer: ISOCustomer?
    @Published private(set) var currentFarmer: ISOFarmer?
    @Published private(set) var farms: [ISOFarm] = []
    @Published private(set) var selectedFarm: ISOFarm?
    @Published private(set) var partfields: [ISOPartfield] = []
    @Published private(set) var selectedPartfield: ISOPartfield?
    @Published private(set) var tasks: [ISOTask] = []
    @Published private(set) var activeTask: ISOTask?

    // MARK: - Database Reference

    private let db = DatabaseManager.shared

    // MARK: - Initialization

    private init() {
        setupDefaultCustomerAndFarmer()
    }

    // MARK: - Setup

    /// Creates default customer and farmer if none exist
    private func setupDefaultCustomerAndFarmer() {
        // Check for existing customer
        let customers = db.getAllCustomers()
        if let customer = customers.first {
            currentCustomer = customer
            loadFarmersForCustomer(customer.id)
        } else {
            // Create default customer (internal identifier)
            if let customer = db.createCustomer(name: "Default Account") {
                currentCustomer = customer
                // Create default farmer
                if let farmer = db.createFarmer(
                    customerId: customer.id,
                    firstName: "Default",
                    lastName: "User"
                ) {
                    currentFarmer = farmer
                }
            }
        }
    }

    private func loadFarmersForCustomer(_ customerId: String) {
        let farmers = db.getFarmersForCustomer(customerId)
        if let farmer = farmers.first {
            currentFarmer = farmer
            loadFarmsForFarmer(farmer.id)
        }
    }

    // MARK: - Farm Operations

    func loadFarmsForFarmer(_ farmerId: String) {
        farms = db.getFarmsForFarmer(farmerId)
        if let first = farms.first {
            selectFarm(first)
        }
    }

    func createFarm(name: String, address: String? = nil, notes: String? = nil) -> ISOFarm? {
        guard let farmerId = currentFarmer?.id else { return nil }

        if let farm = db.createFarm(farmerId: farmerId, name: name, address: address, notes: notes) {
            farms.append(farm)
            return farm
        }
        return nil
    }

    func selectFarm(_ farm: ISOFarm) {
        selectedFarm = farm
        loadPartfieldsForFarm(farm.id)
    }

    func deleteFarm(_ farm: ISOFarm) {
        db.deleteFarm(id: farm.id)
        farms.removeAll { $0.id == farm.id }
        if selectedFarm?.id == farm.id {
            selectedFarm = farms.first
            if let selected = selectedFarm {
                loadPartfieldsForFarm(selected.id)
            } else {
                partfields = []
                selectedPartfield = nil
            }
        }
    }

    // MARK: - Partfield (Field) Operations

    func loadPartfieldsForFarm(_ farmId: String) {
        partfields = db.getPartfieldsForFarm(farmId)
        selectedPartfield = nil
        tasks = []
        activeTask = nil
    }

    /// Creates a new field with boundary polygon
    func createPartfield(
        name: String,
        season: String? = nil,
        cropType: String? = nil,
        boundary: [BoundaryPoint]? = nil
    ) -> ISOPartfield? {
        guard let farmId = selectedFarm?.id else { return nil }

        if var partfield = db.createPartfield(
            farmId: farmId,
            name: name,
            season: season,
            cropType: cropType,
            boundary: boundary
        ) {
            // Calculate area if boundary provided
            if boundary != nil {
                partfield.calculateArea()
                if let area = partfield.areaM2 {
                    db.updatePartfieldBoundary(id: partfield.id, boundary: boundary!, areaM2: area)
                }
            }
            partfields.append(partfield)
            return partfield
        }
        return nil
    }

    /// Creates a field from the current boundary points in the guidance state
    func createPartfieldFromBoundary(
        name: String,
        season: String? = nil,
        cropType: String? = nil,
        boundaryPoints: [(x: Float, z: Float)],
        originCoordinate: CLLocationCoordinate2D
    ) -> ISOPartfield? {
        // Convert local coordinates to WGS84
        let metersPerDegreeLat = 111132.0
        let metersPerDegreeLon = 111132.0 * cos(originCoordinate.latitude * .pi / 180)

        let boundary = boundaryPoints.map { point in
            BoundaryPoint(
                latitude: originCoordinate.latitude + Double(point.z) / metersPerDegreeLat,
                longitude: originCoordinate.longitude + Double(point.x) / metersPerDegreeLon
            )
        }

        return createPartfield(name: name, season: season, cropType: cropType, boundary: boundary)
    }

    func selectPartfield(_ partfield: ISOPartfield) {
        selectedPartfield = partfield
        loadTasksForPartfield(partfield.id)
    }

    func updatePartfieldBoundary(_ partfield: ISOPartfield, boundary: [BoundaryPoint]) {
        var updated = partfield
        updated.boundary = boundary
        updated.calculateArea()

        if let area = updated.areaM2 {
            db.updatePartfieldBoundary(id: partfield.id, boundary: boundary, areaM2: area)
        }

        // Update local array
        if let index = partfields.firstIndex(where: { $0.id == partfield.id }) {
            partfields[index] = updated
        }
        if selectedPartfield?.id == partfield.id {
            selectedPartfield = updated
        }
    }

    func deletePartfield(_ partfield: ISOPartfield) {
        db.deletePartfield(id: partfield.id)
        partfields.removeAll { $0.id == partfield.id }
        if selectedPartfield?.id == partfield.id {
            selectedPartfield = nil
            tasks = []
            activeTask = nil
        }
    }

    // MARK: - Task Operations

    func loadTasksForPartfield(_ partfieldId: String) {
        tasks = db.getTasksForPartfield(partfieldId)
        activeTask = tasks.first { $0.status == .inProgress }
    }

    /// Creates a new task for the selected partfield
    func createTask(
        name: String,
        taskType: TaskType,
        deviceId: String? = nil,
        productId: String? = nil,
        notes: String? = nil
    ) -> ISOTask? {
        guard let partfieldId = selectedPartfield?.id else { return nil }

        if let task = db.createTask(
            partfieldId: partfieldId,
            name: name,
            taskType: taskType,
            deviceId: deviceId,
            productId: productId,
            notes: notes
        ) {
            tasks.insert(task, at: 0)
            return task
        }
        return nil
    }

    func startTask(_ task: ISOTask) {
        // Pause any currently active task
        if let current = activeTask {
            pauseTask(current)
        }

        db.updateTaskStatus(id: task.id, status: .inProgress)

        // Update local state
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.status = .inProgress
            updated.startedAt = Date()
            tasks[index] = updated
            activeTask = updated
        }
    }

    func pauseTask(_ task: ISOTask) {
        db.updateTaskStatus(id: task.id, status: .paused)

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.status = .paused
            tasks[index] = updated
        }

        if activeTask?.id == task.id {
            activeTask = nil
        }
    }

    func completeTask(_ task: ISOTask) {
        db.updateTaskStatus(id: task.id, status: .completed)

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.status = .completed
            updated.completedAt = Date()
            tasks[index] = updated
        }

        if activeTask?.id == task.id {
            activeTask = nil
        }
    }

    func cancelTask(_ task: ISOTask) {
        db.updateTaskStatus(id: task.id, status: .cancelled)

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            var updated = tasks[index]
            updated.status = .cancelled
            tasks[index] = updated
        }

        if activeTask?.id == task.id {
            activeTask = nil
        }
    }

    func deleteTask(_ task: ISOTask) {
        db.deleteTask(id: task.id)
        tasks.removeAll { $0.id == task.id }
        if activeTask?.id == task.id {
            activeTask = nil
        }
    }

    // MARK: - Task Logging

    /// Records position for the active task
    func logPosition(
        latitude: Double,
        longitude: Double,
        heading: Double?,
        speed: Double?,
        additionalData: [String: Any]? = nil
    ) {
        guard let taskId = activeTask?.id else { return }
        db.addTaskLog(
            taskId: taskId,
            latitude: latitude,
            longitude: longitude,
            heading: heading,
            speed: speed,
            data: additionalData
        )
    }

    // MARK: - Coverage

    /// Records coverage cell for the active task
    func recordCoverage(row: Int, col: Int) {
        guard let taskId = activeTask?.id else { return }
        db.addCoverageCell(taskId: taskId, row: row, col: col)
    }

    /// Gets coverage cells for a task
    func getCoverageCells(taskId: String) -> Set<String> {
        return db.getCoverageCells(taskId: taskId)
    }

    /// Gets coverage count for a task
    func getCoverageCount(taskId: String) -> Int {
        return db.getCoverageCount(taskId: taskId)
    }

    // MARK: - Convenience Methods

    /// Gets all partfields across all farms for the current farmer
    func getAllPartfields() -> [ISOPartfield] {
        var allFields: [ISOPartfield] = []
        for farm in farms {
            allFields.append(contentsOf: db.getPartfieldsForFarm(farm.id))
        }
        return allFields
    }

    /// Resolves an entity ID to its type
    func resolveEntityType(id: String) -> EntityType? {
        return db.resolveEntityType(id: id)
    }
}
