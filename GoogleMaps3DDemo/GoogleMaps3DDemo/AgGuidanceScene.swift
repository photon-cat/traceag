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

import SceneKit
import UIKit
import MapKit

class AgGuidanceScene: SCNScene {

    // MARK: - Configuration
    let tileSize: CGFloat = 50.0        // meters per tile
    let guidanceSpacing: CGFloat = 10.0  // meters between lines
    var abHeading: Float = 0            // Set by state

    // MARK: - Modular Nodes
    var gridNode: GuidanceGridNode!
    var vehicleNode: VehicleNode!
    var hitchMarkerNode: HitchMarkerNode!
    var implementNode: ImplementNode!
    var pathNode: PathNode!
    var coverageNode: CoverageNode!
    var scaleIndicatorNode: ScaleIndicatorNode!

    // MARK: - Legacy Nodes (for compatibility during transition)
    var cameraNode: SCNNode!
    var guidanceLinesNode: SCNNode!
    var trackVectorNode: SCNNode!    // Track vector showing predicted path
    var boundaryNode: SCNNode!       // Field boundary visualization

    // MARK: - Tile Management (legacy - grid node handles this now)
    private var loadedTiles: [String: SCNNode] = [:]
    private var currentBackgroundMode: BackgroundMode = .checkerboard
    private var lastGuidanceCenterKey: (x: Int, z: Int)?
    private var lastGuidanceLineIndex: Int?
    private var lastCoverageCenterKey: (row: Int, col: Int)?
    private var lastCoverageGeneration: Int = -1

    // MARK: - State Reference
    weak var state: AgGuidanceState?

    // MARK: - Initialization

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScene()
    }

    private func setupScene() {
        // Dark background for premium look
        background.contents = GuidanceSceneColors.gridBackground
        setupLighting()
        setupModularNodes()
        setupLegacyNodes()
        setupCamera()
    }

    // MARK: - Lighting

    private func setupLighting() {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 800
        rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 600
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 3, y: .pi / 4, z: 0)
        rootNode.addChildNode(directionalLight)
    }

    // MARK: - Modular Node Setup

    private func setupModularNodes() {
        // Guidance grid (dark background with LOD lines)
        gridNode = GuidanceGridNode()
        rootNode.addChildNode(gridNode)

        // Vehicle nav cursor
        vehicleNode = VehicleNode()
        rootNode.addChildNode(vehicleNode)

        // Hitch point marker
        hitchMarkerNode = HitchMarkerNode()
        rootNode.addChildNode(hitchMarkerNode)

        // Implement with COR
        implementNode = ImplementNode()
        rootNode.addChildNode(implementNode)

        // Track vector / path visualization
        pathNode = PathNode()
        rootNode.addChildNode(pathNode)

        // Coverage visualization
        coverageNode = CoverageNode()
        rootNode.addChildNode(coverageNode)

        // Scale indicator
        scaleIndicatorNode = ScaleIndicatorNode()
        scaleIndicatorNode.isHidden = true  // Enable when needed
        rootNode.addChildNode(scaleIndicatorNode)
    }

    // MARK: - Legacy Node Setup (for features not yet migrated)

    private func setupLegacyNodes() {
        guidanceLinesNode = SCNNode()
        rootNode.addChildNode(guidanceLinesNode)

        trackVectorNode = SCNNode()
        rootNode.addChildNode(trackVectorNode)

        boundaryNode = SCNNode()
        rootNode.addChildNode(boundaryNode)
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 1000

        cameraNode.position = SCNVector3(x: 0, y: 30, z: -40)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))

        rootNode.addChildNode(cameraNode)
    }

    // MARK: - Tile Management (Updated to use grid node)

    func updateTiles(centerX: Double, centerZ: Double, renderDistance: Double) {
        // Update grid node position and LOD
        gridNode.updatePosition(
            centerX: Float(centerX),
            centerZ: Float(centerZ),
            extent: Float(renderDistance * 2)
        )

        // Update LOD based on camera height
        let cameraHeight = cameraNode.position.y
        gridNode.updateLOD(cameraHeight: cameraHeight)

        // Update guidance lines
        if shouldRefreshGuidance(centerX: centerX, centerZ: centerZ) {
            updateGuidanceLines(centerX: centerX, centerZ: centerZ, renderDistance: renderDistance)
        }

        // Update coverage using modular node
        if shouldRefreshCoverage(centerX: centerX, centerZ: centerZ, renderDistance: renderDistance) {
            updateCoverageVisualization(centerX: centerX, centerZ: centerZ, renderDistance: renderDistance)
        }
    }

    private func shouldRefreshGuidance(centerX: Double, centerZ: Double) -> Bool {
        guard let state = state else { return false }
        let spacing = max(state.guidanceSpacing, 0.1)
        let key = (x: Int(floor(centerX / spacing)), z: Int(floor(centerZ / spacing)))
        let activeLine = state.currentLineIndex
        let keyChanged = lastGuidanceCenterKey.map { $0.x != key.x || $0.z != key.z } ?? true
        let shouldRefresh = keyChanged || activeLine != lastGuidanceLineIndex
        if shouldRefresh {
            lastGuidanceCenterKey = key
            lastGuidanceLineIndex = activeLine
        }
        return shouldRefresh
    }

    private func shouldRefreshCoverage(centerX: Double, centerZ: Double, renderDistance: Double) -> Bool {
        guard let state = state else { return false }
        let cellSize = max(state.cellSize, 0.1)
        let key = (row: Int(floor(centerZ / cellSize)), col: Int(floor(centerX / cellSize)))
        let generation = state.coverageGeneration
        let keyChanged = lastCoverageCenterKey.map { $0.row != key.row || $0.col != key.col } ?? true
        let shouldRefresh = keyChanged || generation != lastCoverageGeneration
        if shouldRefresh {
            lastCoverageCenterKey = key
            lastCoverageGeneration = generation
        }
        return shouldRefresh
    }

    // MARK: - Guidance Lines

    private func updateGuidanceLines(centerX: Double, centerZ: Double, renderDistance: Double) {
        // Remove old lines
        guidanceLinesNode.childNodes.forEach { $0.removeFromParentNode() }

        guard let state = state else { return }

        // Get lines from guidance engine
        let lines = state.getVisibleGuidanceLines()

        let lineLength: CGFloat = CGFloat(renderDistance * 3)

        for line in lines {
            let lineGeometry = SCNBox(width: 0.3, height: 0.08, length: lineLength, chamferRadius: 0)

            let lineMaterial = SCNMaterial()
            lineMaterial.diffuse.contents = line.isActive ? GuidanceSceneColors.lineActive : GuidanceSceneColors.lineInactive
            lineMaterial.emission.contents = (line.isActive ? GuidanceSceneColors.lineActive : GuidanceSceneColors.lineInactive).withAlphaComponent(0.4)
            lineGeometry.materials = [lineMaterial]

            let lineNode = SCNNode(geometry: lineGeometry)

            // Position at midpoint of the line
            let midX = (line.startPoint.x + line.endPoint.x) / 2
            let midZ = (line.startPoint.y + line.endPoint.y) / 2

            lineNode.position = SCNVector3(
                x: Float(midX),
                y: 0.05,
                z: Float(midZ)
            )

            // Rotate line to align with heading
            lineNode.eulerAngles = SCNVector3(x: 0, y: Float(-line.heading), z: 0)

            guidanceLinesNode.addChildNode(lineNode)
        }
    }

    // MARK: - Coverage Visualization

    private func updateCoverageVisualization(centerX: Double, centerZ: Double, renderDistance: Double) {
        guard let state = state else { return }

        // Use the modular coverage node
        coverageNode.update(
            coveredCells: state.coveredCells,
            centerX: centerX,
            centerZ: centerZ,
            renderDistance: renderDistance,
            generation: state.coverageGeneration
        )
    }

    // MARK: - Public Methods

    func switchCameraMode(_ mode: ViewMode) {
        switch mode {
        case .perspective3D:
            cameraNode.camera?.usesOrthographicProjection = false
            cameraNode.camera?.fieldOfView = 60
        case .topDown2D:
            cameraNode.camera?.usesOrthographicProjection = true
            cameraNode.camera?.orthographicScale = 60
        }
    }

    func updateBackgroundMode(_ mode: BackgroundMode) {
        currentBackgroundMode = mode
        // Background is now handled by grid node, but keep for satellite mode
        if mode == .satellite {
            // Would load satellite imagery
        }
    }

    func updateVehicle(x: Float, z: Float, heading: Float) {
        vehicleNode.update(x: x, z: z, heading: heading)
    }

    func updateImplement(
        workPointX: Float,
        workPointZ: Float,
        workPointHeading: Float,
        hitchX: Float,
        hitchZ: Float,
        implementWidth: Float
    ) {
        // Update hitch marker position
        hitchMarkerNode.update(x: hitchX, z: hitchZ)

        // Update implement with full transform
        implementNode.update(
            workPointX: workPointX,
            workPointZ: workPointZ,
            workPointHeading: workPointHeading,
            hitchX: hitchX,
            hitchZ: hitchZ,
            implementWidth: implementWidth
        )
    }

    // MARK: - Track Vector (Path Visualization)

    /// Updates the path node with track vector data from state
    func updatePathVisualization(
        pathPoints: [CGPoint],
        lookaheadPoint: CGPoint,
        projectedPoint: CGPoint,
        vehicleX: Float,
        vehicleZ: Float,
        lateralError: Double,
        confidence: Double
    ) {
        pathNode.update(
            pathPoints: pathPoints,
            lookaheadPoint: lookaheadPoint,
            projectedPoint: projectedPoint,
            vehicleX: vehicleX,
            vehicleZ: vehicleZ,
            lateralError: lateralError,
            confidence: confidence
        )
    }

    /// Legacy track vector showing predicted vehicle path (keep for now)
    func updateTrackVector(
        x: Float,
        z: Float,
        heading: Float,
        speed: Float,
        yawRate: Float,
        predictionTime: Float
    ) {
        // Update velocity tail on vehicle
        vehicleNode.updateVelocityTail(speed: speed, yawRate: yawRate)

        // Remove old track vector segments
        trackVectorNode.childNodes.forEach { $0.removeFromParentNode() }

        // Only show if moving
        guard speed > 0.1 else { return }

        // Use 5 seconds for lookahead prediction
        let lookaheadTime: Float = 5.0
        let numSegments = 40
        var points: [SCNVector3] = []

        let yawRateDecay: Float = 0.3

        var currentX = x
        var currentZ = z
        var currentHeading = heading
        var currentYawRate = yawRate

        let dt = lookaheadTime / Float(numSegments)

        for i in 0...numSegments {
            points.append(SCNVector3(x: currentX, y: 0.6, z: currentZ))

            if i < numSegments {
                currentX += speed * sin(currentHeading) * dt
                currentZ += speed * cos(currentHeading) * dt
                currentHeading += currentYawRate * dt
                currentYawRate *= (1.0 - yawRateDecay * dt)

                while currentHeading > .pi { currentHeading -= 2 * .pi }
                while currentHeading < -.pi { currentHeading += 2 * .pi }
            }
        }

        // Create line segments with gradient color
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]

            let dx = end.x - start.x
            let dz = end.z - start.z
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.01 else { continue }

            let progress = Float(i) / Float(points.count - 1)
            let alpha = 1.0 - progress * 0.7

            let trackMaterial = SCNMaterial()
            trackMaterial.diffuse.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha))
            trackMaterial.emission.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha * 0.5))

            let segmentGeometry = SCNBox(width: 0.2, height: 0.12, length: CGFloat(length), chamferRadius: 0)
            segmentGeometry.materials = [trackMaterial]

            let segmentNode = SCNNode(geometry: segmentGeometry)
            segmentNode.position = SCNVector3(
                x: (start.x + end.x) / 2,
                y: start.y,
                z: (start.z + end.z) / 2
            )

            let angle = atan2(dx, dz)
            segmentNode.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

            trackVectorNode.addChildNode(segmentNode)
        }
    }

    func updateCamera(vehicleX: Float, vehicleZ: Float, heading: Float, mode: ViewMode, headingMode: HeadingMode = .northUp) {
        let effectiveHeading = headingMode == .headingUp ? heading : 0

        switch mode {
        case .perspective3D:
            let cameraDistance: Float = 30
            let cameraHeight: Float = 15
            let tiltAngle: Float = .pi / 8

            let cameraHeading = headingMode == .headingUp ? heading : heading

            let cameraX = vehicleX - sin(cameraHeading) * cameraDistance
            let cameraZ = vehicleZ - cos(cameraHeading) * cameraDistance

            let smoothing: Float = 0.12
            let currentPos = cameraNode.position
            let targetPos = SCNVector3(x: cameraX, y: cameraHeight, z: cameraZ)

            cameraNode.position = SCNVector3(
                x: currentPos.x + (targetPos.x - currentPos.x) * smoothing,
                y: currentPos.y + (targetPos.y - currentPos.y) * smoothing,
                z: currentPos.z + (targetPos.z - currentPos.z) * smoothing
            )

            cameraNode.eulerAngles = SCNVector3(x: -tiltAngle, y: cameraHeading + .pi, z: 0)

        case .topDown2D:
            cameraNode.position = SCNVector3(x: vehicleX, y: 100, z: vehicleZ)
            cameraNode.eulerAngles = SCNVector3(x: -.pi / 2, y: effectiveHeading + .pi, z: 0)
        }

        // Update grid LOD based on camera height
        gridNode.updateLOD(cameraHeight: cameraNode.position.y)
    }

    func highlightActiveLine(index: Int) {
        // Lines are recreated each frame, so this is handled in updateGuidanceLines
    }

    // MARK: - Field Boundary

    func updateBoundary(points: [(x: Float, z: Float)]) {
        boundaryNode.childNodes.forEach { $0.removeFromParentNode() }

        guard points.count >= 3 else { return }

        let boundaryMaterial = SCNMaterial()
        boundaryMaterial.diffuse.contents = GuidanceSceneColors.boundary
        boundaryMaterial.emission.contents = GuidanceSceneColors.boundary.withAlphaComponent(0.5)

        for i in 0..<points.count {
            let start = points[i]
            let end = points[(i + 1) % points.count]

            let dx = end.x - start.x
            let dz = end.z - start.z
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.1 else { continue }

            let segmentGeometry = SCNBox(width: 0.4, height: 0.2, length: CGFloat(length), chamferRadius: 0)
            segmentGeometry.materials = [boundaryMaterial]

            let segmentNode = SCNNode(geometry: segmentGeometry)
            segmentNode.position = SCNVector3(
                x: (start.x + end.x) / 2,
                y: 0.15,
                z: (start.z + end.z) / 2
            )

            let angle = atan2(dx, dz)
            segmentNode.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

            boundaryNode.addChildNode(segmentNode)
        }
    }

    func clearBoundary() {
        boundaryNode.childNodes.forEach { $0.removeFromParentNode() }
    }

    func clearAllTiles() {
        // Clear coverage
        coverageNode.clearCoverage()

        // Reset grid position
        gridNode.updatePosition(centerX: 0, centerZ: 0, extent: 200)
    }
}
