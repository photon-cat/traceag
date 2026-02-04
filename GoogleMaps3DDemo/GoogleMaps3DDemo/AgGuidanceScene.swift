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

    // MARK: - Nodes
    var tilesNode: SCNNode!
    var cameraNode: SCNNode!
    var vehicleNode: SCNNode!
    var implementNode: SCNNode!      // T-bar implement visualization
    var implementBarNode: SCNNode!   // Horizontal bar (work width)
    var implementLineNode: SCNNode!  // Vertical line (hitch to work point)
    var guidanceLinesNode: SCNNode!
    var coverageNode: SCNNode!
    var trackVectorNode: SCNNode!    // Track vector showing predicted path
    var boundaryNode: SCNNode!       // Field boundary visualization

    // MARK: - Tile Management
    private var loadedTiles: [String: SCNNode] = [:]  // "row_col" -> node
    private var currentBackgroundMode: BackgroundMode = .checkerboard
    private var lastGuidanceCenterKey: (x: Int, z: Int)?
    private var lastGuidanceLineIndex: Int?
    private var lastCoverageCenterKey: (row: Int, col: Int)?
    private var lastCoverageGeneration: Int = -1

    // MARK: - Materials
    private var checkerboardMaterial: SCNMaterial!

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
        background.contents = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        setupMaterials()
        setupLighting()
        setupContainerNodes()
        setupVehicle()
        setupImplement()
        setupCamera()
    }

    // MARK: - Materials

    private func setupMaterials() {
        checkerboardMaterial = createCheckerboardMaterial()
    }

    private func createCheckerboardMaterial() -> SCNMaterial {
        let imageSize = 512
        let tilesPerSide = 50  // 1m tiles for 50m tile

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        let image = renderer.image { context in
            let tilePixels = CGFloat(imageSize) / CGFloat(tilesPerSide)

            for row in 0..<tilesPerSide {
                for col in 0..<tilesPerSide {
                    let isGray = (row + col) % 2 == 0
                    let color: UIColor = isGray ?
                        UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1) :
                        UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
                    context.cgContext.setFillColor(color.cgColor)
                    context.cgContext.fill(CGRect(
                        x: CGFloat(col) * tilePixels,
                        y: CGFloat(row) * tilePixels,
                        width: tilePixels,
                        height: tilePixels
                    ))
                }
            }
        }

        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        return material
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

    // MARK: - Container Nodes

    private func setupContainerNodes() {
        tilesNode = SCNNode()
        rootNode.addChildNode(tilesNode)

        guidanceLinesNode = SCNNode()
        rootNode.addChildNode(guidanceLinesNode)

        coverageNode = SCNNode()
        rootNode.addChildNode(coverageNode)

        trackVectorNode = SCNNode()
        rootNode.addChildNode(trackVectorNode)

        boundaryNode = SCNNode()
        rootNode.addChildNode(boundaryNode)
    }

    // MARK: - Vehicle

    private func setupVehicle() {
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: 0, y: 2.5))
        trianglePath.addLine(to: CGPoint(x: -1.5, y: -1.5))
        trianglePath.addLine(to: CGPoint(x: 1.5, y: -1.5))
        trianglePath.close()

        let shape = SCNShape(path: trianglePath, extrusionDepth: 0.5)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.orange
        material.emission.contents = UIColor.orange.withAlphaComponent(0.4)
        shape.materials = [material]

        vehicleNode = SCNNode(geometry: shape)
        vehicleNode.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        vehicleNode.position = SCNVector3(x: 0, y: 0.5, z: 0)

        rootNode.addChildNode(vehicleNode)
    }

    // MARK: - Implement T-Bar

    private func setupImplement() {
        // Container node for the implement visualization
        implementNode = SCNNode()
        implementNode.position = SCNVector3(x: 0, y: 0.3, z: 0)

        // Green material for implement
        let implementMaterial = SCNMaterial()
        implementMaterial.diffuse.contents = UIColor.green
        implementMaterial.emission.contents = UIColor.green.withAlphaComponent(0.5)

        // Vertical line (hitch to work point) - default 3m length
        let lineGeometry = SCNBox(width: 0.2, height: 0.15, length: 3.0, chamferRadius: 0)
        lineGeometry.materials = [implementMaterial]
        implementLineNode = SCNNode(geometry: lineGeometry)
        implementLineNode.position = SCNVector3(x: 0, y: 0, z: -1.5)  // Offset behind vehicle

        // Horizontal bar (work width) - default 6m width
        let barGeometry = SCNBox(width: 6.0, height: 0.15, length: 0.3, chamferRadius: 0)
        barGeometry.materials = [implementMaterial]
        implementBarNode = SCNNode(geometry: barGeometry)
        implementBarNode.position = SCNVector3(x: 0, y: 0, z: -3.0)  // At end of vertical line

        implementNode.addChildNode(implementLineNode)
        implementNode.addChildNode(implementBarNode)
        rootNode.addChildNode(implementNode)
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

    // MARK: - Tile Management

    func updateTiles(centerX: Double, centerZ: Double, renderDistance: Double) {
        let tilesNeeded = Int(ceil(renderDistance / Double(tileSize))) + 1

        let centerTileX = Int(floor(centerX / Double(tileSize)))
        let centerTileZ = Int(floor(centerZ / Double(tileSize)))

        var newTileKeys = Set<String>()

        // Create tiles around vehicle
        for dx in -tilesNeeded...tilesNeeded {
            for dz in -tilesNeeded...tilesNeeded {
                let tileX = centerTileX + dx
                let tileZ = centerTileZ + dz

                let tileCenterX = (Double(tileX) + 0.5) * Double(tileSize)
                let tileCenterZ = (Double(tileZ) + 0.5) * Double(tileSize)

                let distance = sqrt(pow(tileCenterX - centerX, 2) + pow(tileCenterZ - centerZ, 2))

                if distance <= renderDistance + Double(tileSize) {
                    let key = "\(tileX)_\(tileZ)"
                    newTileKeys.insert(key)

                    if loadedTiles[key] == nil {
                        loadTile(x: tileX, z: tileZ)
                    }
                }
            }
        }

        // Unload distant tiles
        let tilesToRemove = loadedTiles.keys.filter { !newTileKeys.contains($0) }
        for key in tilesToRemove {
            unloadTile(key: key)
        }

        if shouldRefreshGuidance(centerX: centerX, centerZ: centerZ) {
            updateGuidanceLines(centerX: centerX, centerZ: centerZ, renderDistance: renderDistance)
        }

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

    private func loadTile(x: Int, z: Int) {
        let key = "\(x)_\(z)"

        let tileGeometry = SCNPlane(width: tileSize, height: tileSize)
        tileGeometry.materials = [checkerboardMaterial]

        let tileNode = SCNNode(geometry: tileGeometry)
        tileNode.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)

        let posX = (CGFloat(x) + 0.5) * tileSize
        let posZ = (CGFloat(z) + 0.5) * tileSize
        tileNode.position = SCNVector3(x: Float(posX), y: -0.01, z: Float(posZ))

        tilesNode.addChildNode(tileNode)
        loadedTiles[key] = tileNode
    }

    private func unloadTile(key: String) {
        loadedTiles[key]?.removeFromParentNode()
        loadedTiles.removeValue(forKey: key)
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
            lineMaterial.diffuse.contents = line.isActive ? UIColor.yellow : UIColor.cyan
            lineMaterial.emission.contents = (line.isActive ? UIColor.yellow : UIColor.cyan).withAlphaComponent(0.4)
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
        coverageNode.childNodes.forEach { $0.removeFromParentNode() }

        guard let state = state else { return }

        let cellSize = state.cellSize
        let minCol = Int(floor((centerX - renderDistance) / cellSize))
        let maxCol = Int(ceil((centerX + renderDistance) / cellSize))
        let minRow = Int(floor((centerZ - renderDistance) / cellSize))
        let maxRow = Int(ceil((centerZ + renderDistance) / cellSize))

        let coverageMaterial = SCNMaterial()
        coverageMaterial.diffuse.contents = UIColor.green.withAlphaComponent(0.7)
        coverageMaterial.emission.contents = UIColor.green.withAlphaComponent(0.2)

        // Batch into strips per row for performance
        for row in minRow...maxRow {
            var stripStart: Int? = nil

            for col in minCol...maxCol {
                if state.isCellCovered(row: row, col: col) {
                    if stripStart == nil {
                        stripStart = col
                    }
                } else if let start = stripStart {
                    addCoverageStrip(row: row, startCol: start, endCol: col - 1, cellSize: cellSize, material: coverageMaterial)
                    stripStart = nil
                }
            }

            if let start = stripStart {
                addCoverageStrip(row: row, startCol: start, endCol: maxCol, cellSize: cellSize, material: coverageMaterial)
            }
        }
    }

    private func addCoverageStrip(row: Int, startCol: Int, endCol: Int, cellSize: Double, material: SCNMaterial) {
        let width = Double(endCol - startCol + 1) * cellSize
        let height: Double = 0.1

        let geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(cellSize), chamferRadius: 0)
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        let centerX = Double(startCol) * cellSize + width / 2
        let centerZ = Double(row) * cellSize + cellSize / 2
        node.position = SCNVector3(x: Float(centerX), y: Float(height / 2) + 0.02, z: Float(centerZ))

        coverageNode.addChildNode(node)
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
        // Reload all tiles with new material
        let keys = Array(loadedTiles.keys)
        for key in keys {
            unloadTile(key: key)
        }
        // Tiles will be reloaded on next update
    }

    func updateVehicle(x: Float, z: Float, heading: Float) {
        vehicleNode.position = SCNVector3(x: x, y: 0.5, z: z)
        // Triangle tip points +Y in local space, rotated to lay flat on XZ plane
        // Y rotation matches camera so vehicle always points "up" on screen
        vehicleNode.eulerAngles = SCNVector3(x: -.pi / 2, y: heading + .pi, z: 0)
    }

    func updateImplement(
        workPointX: Float,
        workPointZ: Float,
        workPointHeading: Float,
        hitchX: Float,
        hitchZ: Float,
        implementWidth: Float
    ) {
        // T-bar visualization:
        // - Horizontal bar at HITCH (connects to tractor)
        // - Vertical line extends from hitch back to work point
        // - Whole T pivots around the hitch point

        // Calculate the line length from hitch to work point
        let dx = workPointX - hitchX
        let dz = workPointZ - hitchZ
        let lineLength = sqrt(dx * dx + dz * dz)

        // Update line geometry (vertical part of T - from hitch to work point)
        if let lineGeometry = implementLineNode.geometry as? SCNBox {
            let newLine = SCNBox(width: 0.2, height: 0.15, length: CGFloat(max(0.5, lineLength)), chamferRadius: 0)
            newLine.materials = lineGeometry.materials
            implementLineNode.geometry = newLine
        }

        // Update bar geometry (horizontal part of T - at hitch)
        if let barGeometry = implementBarNode.geometry as? SCNBox {
            let newBar = SCNBox(width: CGFloat(implementWidth), height: 0.15, length: 0.3, chamferRadius: 0)
            newBar.materials = barGeometry.materials
            implementBarNode.geometry = newBar
        }

        // Position the whole T at the hitch point (pivot point)
        // The T rotates around the hitch based on implement heading
        implementNode.position = SCNVector3(x: hitchX, y: 0.3, z: hitchZ)
        implementNode.eulerAngles = SCNVector3(x: 0, y: -workPointHeading, z: 0)

        // Bar is at hitch (local origin of parent)
        implementBarNode.position = SCNVector3(x: 0, y: 0, z: 0)
        implementBarNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)

        // Line extends backward from hitch to work point
        // Position at half the line length behind hitch (in local -Z direction)
        implementLineNode.position = SCNVector3(x: 0, y: 0, z: -lineLength / 2)
        implementLineNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
    }

    // MARK: - Track Vector

    /// Updates the track vector showing predicted path for the next `predictionTime` seconds.
    /// Uses proper kinematic equations for smooth curved paths when turning.
    func updateTrackVector(
        x: Float,
        z: Float,
        heading: Float,
        speed: Float,
        yawRate: Float,
        predictionTime: Float
    ) {
        // Remove old track vector segments
        trackVectorNode.childNodes.forEach { $0.removeFromParentNode() }

        // Only show if moving
        guard speed > 0.1 else { return }

        // Use 5 seconds for lookahead prediction
        let lookaheadTime: Float = 5.0
        let numSegments = 40  // More segments for smoother curves
        var points: [SCNVector3] = []

        // Smooth the yaw rate with decay for more natural prediction
        // Assumes yaw rate gradually returns to zero over time
        let yawRateDecay: Float = 0.3  // How quickly turn straightens out

        // Current position and heading
        var currentX = x
        var currentZ = z
        var currentHeading = heading
        var currentYawRate = yawRate

        // Use integration for smooth path prediction
        let dt = lookaheadTime / Float(numSegments)

        for i in 0...numSegments {
            points.append(SCNVector3(x: currentX, y: 0.6, z: currentZ))

            if i < numSegments {
                // Integrate position using current heading
                // dx/dt = speed * sin(heading)
                // dz/dt = speed * cos(heading)
                currentX += speed * sin(currentHeading) * dt
                currentZ += speed * cos(currentHeading) * dt

                // Update heading based on current yaw rate
                currentHeading += currentYawRate * dt

                // Decay yaw rate toward zero (natural straightening)
                currentYawRate *= (1.0 - yawRateDecay * dt)

                // Normalize heading
                while currentHeading > .pi { currentHeading -= 2 * .pi }
                while currentHeading < -.pi { currentHeading += 2 * .pi }
            }
        }

        // Create line segments with gradient color (brighter near vehicle)
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]

            let dx = end.x - start.x
            let dz = end.z - start.z
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.01 else { continue }

            // Color gradient: bright cyan near vehicle, fading to transparent
            let progress = Float(i) / Float(points.count - 1)
            let alpha = 1.0 - progress * 0.7  // Fade from 1.0 to 0.3

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

            // Rotate to align with segment direction
            let angle = atan2(dx, dz)
            segmentNode.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

            trackVectorNode.addChildNode(segmentNode)
        }
    }

    func updateCamera(vehicleX: Float, vehicleZ: Float, heading: Float, mode: ViewMode, headingMode: HeadingMode = .northUp) {
        // Determine effective heading for camera rotation
        // In heading-up mode, camera rotates with vehicle so vehicle always points up
        // In north-up mode, camera stays fixed (north is up)
        let effectiveHeading = headingMode == .headingUp ? heading : 0

        switch mode {
        case .perspective3D:
            // Camera behind vehicle, looking forward along heading
            let cameraDistance: Float = 30
            let cameraHeight: Float = 15
            let tiltAngle: Float = .pi / 8  // How much camera looks down

            // In heading-up mode, camera follows heading; in north-up, always behind
            let cameraHeading = headingMode == .headingUp ? heading : heading

            // Position camera behind vehicle (opposite of heading direction)
            let cameraX = vehicleX - sin(cameraHeading) * cameraDistance
            let cameraZ = vehicleZ - cos(cameraHeading) * cameraDistance

            // Smooth camera movement
            let smoothing: Float = 0.12
            let currentPos = cameraNode.position
            let targetPos = SCNVector3(x: cameraX, y: cameraHeight, z: cameraZ)

            cameraNode.position = SCNVector3(
                x: currentPos.x + (targetPos.x - currentPos.x) * smoothing,
                y: currentPos.y + (targetPos.y - currentPos.y) * smoothing,
                z: currentPos.z + (targetPos.z - currentPos.z) * smoothing
            )

            // Set camera rotation explicitly (no roll)
            // X: tilt down to look at ground ahead
            // Y: rotate to face heading direction
            // Z: 0 (no roll - keeps horizon level)
            cameraNode.eulerAngles = SCNVector3(x: -tiltAngle, y: cameraHeading + .pi, z: 0)

        case .topDown2D:
            // Camera directly above vehicle
            cameraNode.position = SCNVector3(x: vehicleX, y: 100, z: vehicleZ)
            // X: -90° to look straight down
            // Y: rotate based on heading mode
            //    heading-up: rotate so vehicle heading points to top of screen
            //    north-up: keep north at top (Y = 0)
            // Z: 0 (no roll)
            cameraNode.eulerAngles = SCNVector3(x: -.pi / 2, y: effectiveHeading + .pi, z: 0)
        }
    }

    func highlightActiveLine(index: Int) {
        // Lines are recreated each frame, so this is handled in updateGuidanceLines
    }

    // MARK: - Field Boundary

    func updateBoundary(points: [(x: Float, z: Float)]) {
        // Remove old boundary
        boundaryNode.childNodes.forEach { $0.removeFromParentNode() }

        guard points.count >= 3 else { return }

        // Create boundary line segments
        let boundaryMaterial = SCNMaterial()
        boundaryMaterial.diffuse.contents = UIColor.red
        boundaryMaterial.emission.contents = UIColor.red.withAlphaComponent(0.5)

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

            // Rotate to align with segment direction
            let angle = atan2(dx, dz)
            segmentNode.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

            boundaryNode.addChildNode(segmentNode)
        }
    }

    func clearBoundary() {
        boundaryNode.childNodes.forEach { $0.removeFromParentNode() }
    }

    func clearAllTiles() {
        // Remove all loaded tiles
        for key in loadedTiles.keys {
            unloadTile(key: key)
        }
        // Clear coverage
        coverageNode.childNodes.forEach { $0.removeFromParentNode() }
    }
}
