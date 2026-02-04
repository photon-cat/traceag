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

import SwiftUI
import SceneKit
import CoreLocation
import Combine

// MARK: - Enums

enum ViewMode: String, CaseIterable {
    case perspective3D = "3D"
    case topDown2D = "2D"
}

enum BackgroundMode: String, CaseIterable {
    case checkerboard = "Grid"
    case satellite = "Satellite"
}

enum ControlMode: String, CaseIterable {
    case autoFollow = "Auto"
    case manual = "Manual"
}

enum HeadingMode: String, CaseIterable {
    case northUp = "North Up"
    case headingUp = "Heading Up"
}

enum ABPointState: String {
    case none = "Set A"
    case aSet = "Set B"
    case complete = "New AB"
}

// MARK: - AgGuidanceState

class AgGuidanceState: ObservableObject {
    // MARK: - Published UI Properties

    @Published var viewMode: ViewMode = .perspective3D
    @Published var backgroundMode: BackgroundMode = .checkerboard
    @Published var controlMode: ControlMode = .autoFollow
    @Published var headingMode: HeadingMode = .northUp
    @Published var coveragePercent: Double = 0
    @Published var isRunning: Bool = false
    @Published var implementActive: Bool = true

    // MARK: - Guidance Published Properties

    @Published var currentLineIndex: Int = 0
    @Published var crossTrackError: Double = 0
    @Published var alongTrackDistance: Double = 0
    @Published var isPastEndPoint: Bool = false
    @Published var abPointState: ABPointState = .none

    // MARK: - Position Source

    @Published var positionSourceType: PositionSourceType = .simulator {
        didSet {
            switchPositionSource()
        }
    }

    private var positionSource: PositionSource!
    private var positionCancellable: AnyCancellable?
    private var statusCancellable: AnyCancellable?

    // MARK: - GNSS Status

    @Published var gnssStatus: GNSSStatus?
    @Published var gnssAccuracy: Double = -1
    @Published var gnssUpdateRate: Double = 0
    @Published var isExternalGNSS: Bool = false

    // MARK: - Simulator Settings

    @Published var simulatorSpeed: Double = 3.0 {
        didSet {
            if let sim = positionSource as? SimulatorPositionSource {
                sim.speed = simulatorSpeed
            }
        }
    }

    @Published var simulatorInitialCoordinate: CLLocationCoordinate2D {
        didSet {
            if let sim = positionSource as? SimulatorPositionSource {
                sim.initialCoordinate = simulatorInitialCoordinate
            }
        }
    }

    // MARK: - Guidance Engine

    private var guidanceEngine: StraightABGuidance?

    @Published var guidanceSpacing: Double = 10.0 {
        didSet {
            guidanceEngine?.lineSpacing = guidanceSpacing
        }
    }

    @Published var linesDirection: LinesDirection = .both {
        didSet {
            guidanceEngine?.linesDirection = linesDirection
        }
    }

    @Published var implementWidth: Double = 6.0

    // MARK: - Vehicle Configuration

    @Published var vehicleConfig: VehicleConfiguration = VehicleConfiguration() {
        didSet {
            // Sync implement width with work area width
            if implementWidth != vehicleConfig.implement.workAreaWidth {
                implementWidth = vehicleConfig.implement.workAreaWidth
            }
            // Update work point calculator with new profiles
            workPointCalculator.machineProfile = vehicleConfig.machine
            workPointCalculator.implementProfile = vehicleConfig.implement
        }
    }

    // MARK: - AB Line

    @Published var abLine: ABLine?

    var abHeadingDegrees: Double {
        get {
            (abLine?.heading ?? 0) * 180 / .pi
        }
        set {
            abLine?.manualHeading = newValue * .pi / 180
            if let ab = abLine {
                guidanceEngine = StraightABGuidance(
                    abLine: ab,
                    lineSpacing: guidanceSpacing,
                    linesDirection: linesDirection
                )
            }
        }
    }

    // MARK: - Vehicle State (Antenna Position)

    @Published var vehicleCoordinate: CLLocationCoordinate2D
    @Published var vehicleHeading: Double = 0
    @Published var vehicleSpeed: Double = 0
    @Published var vehicleYawRate: Double = 0

    var vehicleLocalX: Double = 0
    var vehicleLocalZ: Double = 0
    private var lastHeading: Double = 0
    private var lastHeadingTime: CFTimeInterval = 0

    // MARK: - Work Point State (Calculated from Antenna + Geometry)

    @Published var workPointX: Double = 0
    @Published var workPointZ: Double = 0
    @Published var workPointHeading: Double = 0

    // Hitch position for implement visualization
    var hitchX: Double = 0
    var hitchZ: Double = 0

    private lazy var workPointCalculator: WorkPointCalculator = {
        WorkPointCalculator(machine: vehicleConfig.machine, implement: vehicleConfig.implement)
    }()

    // MARK: - World Configuration

    let renderDistance: Double = 200.0
    let tileSize: Double = 50.0

    // MARK: - Coverage Grid

    var coveredCells: Set<String> = []
    let cellSize: Double = 1.0

    // MARK: - Scene Reference

    weak var scene: AgGuidanceScene?

    // MARK: - Update Loop

    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var frameCount: Int = 0

    // MARK: - Steering (Manual Mode)

    var steeringValue: Double = 0 {
        didSet {
            if let sim = positionSource as? SimulatorPositionSource {
                sim.steeringInput = steeringValue
            }
        }
    }

    // MARK: - Simulator Controls

    /// Increase simulator speed by increment (default 0.5 m/s)
    func increaseSimulatorSpeed(by increment: Double = 0.5) {
        simulatorSpeed = min(simulatorSpeed + increment, 20.0) // Max 20 m/s
    }

    /// Decrease simulator speed by increment (default 0.5 m/s)
    func decreaseSimulatorSpeed(by increment: Double = 0.5) {
        simulatorSpeed = max(simulatorSpeed - increment, 0.0) // Min 0 m/s
    }

    /// Apply continuous left turn input to simulator
    func simulatorTurnLeft() {
        if let sim = positionSource as? SimulatorPositionSource {
            sim.steeringInput = -1.0
        }
    }

    /// Apply continuous right turn input to simulator
    func simulatorTurnRight() {
        if let sim = positionSource as? SimulatorPositionSource {
            sim.steeringInput = 1.0
        }
    }

    /// Release turn input
    func simulatorReleaseTurn() {
        if let sim = positionSource as? SimulatorPositionSource {
            sim.steeringInput = 0
        }
    }

    /// Get current simulator for direct access
    var simulator: SimulatorPositionSource? {
        positionSource as? SimulatorPositionSource
    }

    // MARK: - Initialization

    init() {
        let defaultOrigin = CLLocationCoordinate2D(latitude: 38.06517, longitude: -79.05179)
        self.simulatorInitialCoordinate = defaultOrigin
        self.vehicleCoordinate = defaultOrigin

        // Create default position source
        let simulator = SimulatorPositionSource(
            initialCoordinate: defaultOrigin,
            speed: simulatorSpeed
        )
        self.positionSource = simulator

        setupPositionSubscription()
    }

    // MARK: - Position Source Management

    private func switchPositionSource() {
        positionSource.stop()
        positionCancellable?.cancel()

        switch positionSourceType {
        case .simulator:
            let simulator = SimulatorPositionSource(
                initialCoordinate: simulatorInitialCoordinate,
                speed: simulatorSpeed
            )
            if let ab = abLine {
                simulator.setHeading(ab.heading)
            }
            positionSource = simulator

        case .gnss:
            positionSource = GNSSPositionSource()
        }

        setupPositionSubscription()

        if isRunning {
            positionSource.start()
        }
    }

    private func setupPositionSubscription() {
        positionCancellable = positionSource.positionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handlePositionUpdate(update)
            }

        // Subscribe to GNSS status updates
        statusCancellable = positionSource.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusUpdate(status)
            }
    }

    private func handleStatusUpdate(_ status: GNSSStatus) {
        gnssStatus = status
        gnssAccuracy = status.horizontalAccuracy
        gnssUpdateRate = status.updateRate
        isExternalGNSS = status.isExternalGNSS
    }

    // MARK: - Position Handling

    private func handlePositionUpdate(_ update: PositionUpdate) {
        vehicleCoordinate = update.coordinate
        vehicleHeading = update.heading
        vehicleSpeed = update.speed

        // Convert antenna position to local coordinates
        if let engine = guidanceEngine {
            let antennaLocal = engine.wgs84ToLocal(update.coordinate)
            vehicleLocalX = antennaLocal.x
            vehicleLocalZ = antennaLocal.z

            // Calculate work point position from antenna using vehicle geometry
            // P_workpoint = f(P_antenna, θ_tractor, machine_config, implement_config)
            let workPoint = workPointCalculator.calculateWorkPoint(
                antennaX: antennaLocal.x,
                antennaZ: antennaLocal.z,
                tractorHeading: update.heading,
                steerAngle: controlMode == .manual ? steeringValue * vehicleConfig.machine.maxSteerAngleRadians : nil,
                deltaTime: 0.016
            )

            workPointX = workPoint.x
            workPointZ = workPoint.z
            workPointHeading = workPoint.heading

            // Get hitch position for implement visualization
            hitchX = workPointCalculator.currentHitchX
            hitchZ = workPointCalculator.currentHitchZ

            // Calculate guidance using WORK POINT position (not antenna)
            // This ensures the implement stays on line, not the tractor
            let guidance = engine.calculateGuidance(
                localX: workPoint.x,
                localZ: workPoint.z,
                vehicleHeading: workPoint.heading,
                targetLineIndex: currentLineIndex
            )

            crossTrackError = guidance.crossTrackError
            alongTrackDistance = guidance.alongTrackDistance
            isPastEndPoint = guidance.isPastEndPoint

            // Auto-switch to nearest line when close enough and roughly aligned
            let nearestLine = guidance.nearestLineIndex
            if nearestLine != currentLineIndex {
                // Check if we're close to the nearest line (within half line spacing)
                let distanceToNearest = abs(guidance.crossTrackError + Double(currentLineIndex - nearestLine) * guidanceSpacing)
                let switchThreshold = guidanceSpacing * 0.4  // Switch when within 40% of line spacing

                // Check if heading is roughly aligned with AB line (within 45 degrees either direction)
                let abHeading = engine.abLine.heading
                var headingDiff = abs(workPoint.heading - abHeading)
                // Normalize to 0-π range (allow traveling in either direction)
                while headingDiff > .pi { headingDiff -= .pi }
                if headingDiff > .pi / 2 { headingDiff = .pi - headingDiff }

                let isAligned = headingDiff < (.pi / 4)  // Within 45 degrees

                if distanceToNearest < switchThreshold && isAligned {
                    currentLineIndex = nearestLine
                }
            }

            // Auto-follow mode: steer toward line (target is work point on line)
            if controlMode == .autoFollow,
               let sim = positionSource as? SimulatorPositionSource {
                let headingError = guidance.steerToHeading - update.heading
                var normalizedError = headingError
                while normalizedError > .pi { normalizedError -= 2 * .pi }
                while normalizedError < -.pi { normalizedError += 2 * .pi }

                // Apply steering correction
                sim.steeringInput = -normalizedError * 0.5
            }
        } else {
            // No AB line yet - use position relative to initial coordinate
            let metersPerDegreeLat = 111132.0
            let metersPerDegreeLon = 111132.0 * cos(simulatorInitialCoordinate.latitude * .pi / 180)

            vehicleLocalX = (update.coordinate.longitude - simulatorInitialCoordinate.longitude) * metersPerDegreeLon
            vehicleLocalZ = (update.coordinate.latitude - simulatorInitialCoordinate.latitude) * metersPerDegreeLat

            // Work point without AB line - just offset from antenna
            let workPoint = workPointCalculator.calculateWorkPoint(
                antennaX: vehicleLocalX,
                antennaZ: vehicleLocalZ,
                tractorHeading: update.heading
            )
            workPointX = workPoint.x
            workPointZ = workPoint.z
            workPointHeading = workPoint.heading
        }
    }

    // MARK: - Simulation Control

    func startSimulation() {
        guard !isRunning else { return }
        isRunning = true

        positionSource.start()

        // Start render update loop
        displayLink = CADisplayLink(target: self, selector: #selector(renderUpdate))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }

    func stopSimulation() {
        displayLink?.invalidate()
        displayLink = nil
        positionSource.stop()
        isRunning = false
    }

    @objc private func renderUpdate(link: CADisplayLink) {
        // Calculate yaw rate from heading change
        let currentTime = CACurrentMediaTime()
        if lastHeadingTime > 0 {
            let dt = currentTime - lastHeadingTime
            if dt > 0 {
                var headingDiff = vehicleHeading - lastHeading
                // Normalize to -π to π
                while headingDiff > .pi { headingDiff -= 2 * .pi }
                while headingDiff < -.pi { headingDiff += 2 * .pi }
                vehicleYawRate = headingDiff / dt
            }
        }
        lastHeading = vehicleHeading
        lastHeadingTime = currentTime

        // Update scene rendering
        scene?.updateVehicle(
            x: Float(vehicleLocalX),
            z: Float(vehicleLocalZ),
            heading: Float(vehicleHeading)
        )

        // Update implement T-bar visualization
        scene?.updateImplement(
            workPointX: Float(workPointX),
            workPointZ: Float(workPointZ),
            workPointHeading: Float(workPointHeading),
            hitchX: Float(hitchX),
            hitchZ: Float(hitchZ),
            implementWidth: Float(vehicleConfig.implement.workAreaWidth)
        )

        // Update track vector showing predicted path (5 seconds lookahead)
        scene?.updateTrackVector(
            x: Float(vehicleLocalX),
            z: Float(vehicleLocalZ),
            heading: Float(vehicleHeading),
            speed: Float(vehicleSpeed),
            yawRate: Float(vehicleYawRate),
            predictionTime: 5.0
        )

        scene?.updateCamera(
            vehicleX: Float(vehicleLocalX),
            vehicleZ: Float(vehicleLocalZ),
            heading: Float(vehicleHeading),
            mode: viewMode,
            headingMode: headingMode
        )

        // Record coverage only when implement is active
        if implementActive {
            recordCoverage()
        }

        // Update tiles periodically
        frameCount += 1
        if frameCount % 10 == 0 {
            scene?.updateTiles(
                centerX: vehicleLocalX,
                centerZ: vehicleLocalZ,
                renderDistance: renderDistance
            )
            updateCoveragePercent()
        }
    }

    // MARK: - Coverage Tracking

    private func recordCoverage() {
        // Coverage is painted at WORK POINT position, not antenna
        // This represents where the implement is actually working
        let halfWidth = vehicleConfig.implement.workAreaWidth / 2
        let perpX = cos(workPointHeading)
        let perpZ = -sin(workPointHeading)

        let step = cellSize / 2
        var offset = -halfWidth
        while offset <= halfWidth {
            let sampleX = workPointX + offset * perpX
            let sampleZ = workPointZ + offset * perpZ

            let col = Int(floor(sampleX / cellSize))
            let row = Int(floor(sampleZ / cellSize))

            coveredCells.insert("\(row)_\(col)")
            offset += step
        }
    }

    private func updateCoveragePercent() {
        let cellsInRange = Int(pow(renderDistance * 2 / cellSize, 2))
        coveragePercent = min(100, Double(coveredCells.count) / Double(cellsInRange) * 100)
    }

    func isCellCovered(
        
        row: Int, col: Int) -> Bool {
        coveredCells.contains("\(row)_\(col)")
    }

    // MARK: - AB Line Actions

    func setABPoint() {
        switch abPointState {
        case .none:
            // Set A point
            let newAB = ABLine(pointA: vehicleCoordinate, heading: vehicleHeading)
            abLine = newAB

            guidanceEngine = StraightABGuidance(
                abLine: newAB,
                lineSpacing: guidanceSpacing,
                linesDirection: linesDirection
            )

            // Reset local coordinates relative to new A point
            vehicleLocalX = 0
            vehicleLocalZ = 0
            currentLineIndex = 0

            // Reset work point calculator and recalculate positions at origin
            workPointCalculator.reset()
            let workPoint = workPointCalculator.calculateWorkPoint(
                antennaX: 0,
                antennaZ: 0,
                tractorHeading: vehicleHeading
            )
            workPointX = workPoint.x
            workPointZ = workPoint.z
            workPointHeading = workPoint.heading
            hitchX = workPointCalculator.currentHitchX
            hitchZ = workPointCalculator.currentHitchZ

            abPointState = .aSet

            // Update simulator heading if in simulator mode
            if let sim = positionSource as? SimulatorPositionSource {
                sim.setHeading(vehicleHeading)
            }

            scene?.clearAllTiles()

        case .aSet:
            // Set B point
            abLine?.pointB = vehicleCoordinate

            if let ab = abLine {
                guidanceEngine = StraightABGuidance(
                    abLine: ab,
                    lineSpacing: guidanceSpacing,
                    linesDirection: linesDirection
                )
                _ = FieldTaskManager.shared.createGuidanceLineFromABLine(ab, spacing: guidanceSpacing)
            }

            abPointState = .complete

        case .complete:
            // Start new AB line
            abLine = nil
            guidanceEngine = nil
            abPointState = .none
            coveredCells.removeAll()
            coveragePercent = 0
            workPointCalculator.reset()
            scene?.clearAllTiles()
        }
    }

    func clearCoverage() {
        coveredCells.removeAll()
        coveragePercent = 0
    }

    // MARK: - Field Boundary

    /// Demo boundary points in local coordinates
    @Published var boundaryPoints: [(x: Float, z: Float)] = []

    func createDemoBoundary() {
        // Create 20x20m demo boundary centered at origin
        boundaryPoints = [
            (x: -10, z: -10),
            (x: 10, z: -10),
            (x: 10, z: 10),
            (x: -10, z: 10)
        ]

        // Update scene visualization
        scene?.updateBoundary(points: boundaryPoints)

        // Reset state for new task
        coveredCells.removeAll()
        coveragePercent = 0
        abLine = nil
        guidanceEngine = nil
        abPointState = .none

        // Position vehicle at start (bottom center, facing north)
        if let sim = positionSource as? SimulatorPositionSource {
            sim.reset()
            vehicleLocalX = 0
            vehicleLocalZ = -5
            sim.setHeading(0)  // Face north
        }
    }

    func clearBoundary() {
        boundaryPoints.removeAll()
        scene?.clearBoundary()
    }

    // MARK: - View Mode

    func updateViewMode(_ mode: ViewMode) {
        viewMode = mode
        scene?.switchCameraMode(mode)
    }

    func updateBackgroundMode(_ mode: BackgroundMode) {
        backgroundMode = mode
        scene?.updateBackgroundMode(mode)
    }

    // MARK: - Line Navigation

    func nextLine() {
        currentLineIndex += 1
        // Flip direction in simulator
        if let sim = positionSource as? SimulatorPositionSource {
            sim.setHeading(sim.heading + .pi)
        }
    }

    func previousLine() {
        currentLineIndex -= 1
        // Flip direction in simulator
        if let sim = positionSource as? SimulatorPositionSource {
            sim.setHeading(sim.heading + .pi)
        }
    }

    // MARK: - Guidance Data for Scene

    func getVisibleGuidanceLines() -> [GuidanceLine] {
        return guidanceEngine?.getVisibleLines(
            centerX: vehicleLocalX,
            centerZ: vehicleLocalZ,
            renderDistance: renderDistance,
            activeLineIndex: currentLineIndex
        ) ?? []
    }
}
