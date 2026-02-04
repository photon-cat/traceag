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

private enum GridDetail {
    case fine
    case coarse
}

class AgGuidanceScene: SCNScene {

    // MARK: - Configuration
    let tileSize: CGFloat = 50.0        // meters per tile
    let guidanceSpacing: CGFloat = 10.0  // meters between lines
    var abHeading: Float = 0            // Set by state

    // MARK: - Nodes
    var tilesNode: SCNNode!
    var cameraNode: SCNNode!
    var vehicleNode: SCNNode!
    var implementNode: SCNNode!      // Implement visualization
    var implementFrameNode: SCNNode!
    var implementConnectorNode: SCNNode!
    var implementCorNode: SCNNode!
    var hitchMarkerNode: SCNNode!
    var rearAxleMarkerNode: SCNNode!
    var headingTailNode: SCNNode!
    var guidanceLinesNode: SCNNode!
    var coverageNode: SCNNode!
    var trackVectorNode: SCNNode!    // Heading stability tail
    var guidancePathNode: SCNNode!
    var guidanceIndicatorNode: SCNNode!
    var lookaheadNode: SCNNode!
    var headingErrorNode: SCNNode!
    var debugNode: SCNNode!
    var boundaryNode: SCNNode!       // Field boundary visualization

    // MARK: - Tile Management
    private var loadedTiles: [String: SCNNode] = [:]  // "row_col" -> node
    private var currentBackgroundMode: BackgroundMode = .checkerboard
    private var currentGridDetail: GridDetail = .fine
    private var lastGuidanceCenterKey: (x: Int, z: Int)?
    private var lastGuidanceLineIndex: Int?
    private var lastCoverageCenterKey: (row: Int, col: Int)?
    private var lastCoverageGeneration: Int = -1

    // MARK: - Materials
    private var gridFineMaterial: SCNMaterial!
    private var gridCoarseMaterial: SCNMaterial!
    private var satelliteMaterial: SCNMaterial!
    private var coverageMaterial: SCNMaterial!

    private var currentZoomScale: Float = 60
    private var lastVehiclePosition = SCNVector3Zero
    private var lastVehicleHeading: Float = 0

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
        background.contents = UIColor(red: 0.06, green: 0.08, blue: 0.1, alpha: 1.0)
        setupMaterials()
        setupLighting()
        setupContainerNodes()
        setupVehicle()
        setupImplement()
        setupCamera()
    }

    // MARK: - Materials

    private func setupMaterials() {
        gridFineMaterial = createGridMaterial(minorMeters: 1, majorMeters: 5)
        gridCoarseMaterial = createGridMaterial(minorMeters: 5, majorMeters: 25)
        satelliteMaterial = createSatellitePlaceholderMaterial()
        coverageMaterial = createCoverageMaterial()
    }

    private func createGridMaterial(minorMeters: Int, majorMeters: Int) -> SCNMaterial {
        let imageSize = 512
        let background = UIColor(red: 0.06, green: 0.08, blue: 0.1, alpha: 1.0)
        let minorLine = UIColor.white.withAlphaComponent(0.06)
        let majorLine = UIColor.white.withAlphaComponent(0.16)
        let noise = UIColor.white.withAlphaComponent(0.02)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(background.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))

            let metersPerTile = Int(tileSize)
            let minorCells = max(1, metersPerTile / minorMeters)
            let minorStep = CGFloat(imageSize) / CGFloat(minorCells)
            let majorEvery = max(1, majorMeters / minorMeters)

            for i in 0...minorCells {
                let isMajor = i % majorEvery == 0
                let color = isMajor ? majorLine : minorLine
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(isMajor ? 1.2 : 0.6)

                let pos = CGFloat(i) * minorStep
                cg.move(to: CGPoint(x: pos, y: 0))
                cg.addLine(to: CGPoint(x: pos, y: imageSize))
                cg.move(to: CGPoint(x: 0, y: pos))
                cg.addLine(to: CGPoint(x: imageSize, y: pos))
                cg.strokePath()
            }

            for _ in 0..<600 {
                let x = CGFloat.random(in: 0..<CGFloat(imageSize))
                let y = CGFloat.random(in: 0..<CGFloat(imageSize))
                cg.setFillColor(noise.cgColor)
                cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }

    private func createSatellitePlaceholderMaterial() -> SCNMaterial {
        let imageSize = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        let image = renderer.image { context in
            let cg = context.cgContext
            let base = UIColor(red: 0.1, green: 0.12, blue: 0.14, alpha: 1.0)
            cg.setFillColor(base.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))

            for _ in 0..<300 {
                let x = CGFloat.random(in: 0..<CGFloat(imageSize))
                let y = CGFloat.random(in: 0..<CGFloat(imageSize))
                let w = CGFloat.random(in: 10...40)
                let h = CGFloat.random(in: 10...40)
                let tint = UIColor.white.withAlphaComponent(0.02)
                cg.setFillColor(tint.cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
        }

        let material = SCNMaterial()
        material.diffuse.contents = image
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }

    private func createCoverageMaterial() -> SCNMaterial {
        let imageSize = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))

            let stripeColor = UIColor.white.withAlphaComponent(0.08)
            for i in stride(from: 0, to: imageSize, by: 18) {
                cg.setStrokeColor(stripeColor.cgColor)
                cg.setLineWidth(2)
                cg.move(to: CGPoint(x: 0, y: CGFloat(i)))
                cg.addLine(to: CGPoint(x: CGFloat(imageSize), y: CGFloat(i + 8)))
                cg.strokePath()
            }
        }

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 0.45)
        material.emission.contents = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 0.15)
        material.transparent.contents = image
        material.blendMode = .alpha
        material.isDoubleSided = true
        return material
    }

    // MARK: - Lighting

    private func setupLighting() {
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 650
        rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 900
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 3, y: .pi / 4, z: 0)
        rootNode.addChildNode(directionalLight)
    }

    // MARK: - Container Nodes

    private func setupContainerNodes() {
        tilesNode = SCNNode()
        rootNode.addChildNode(tilesNode)

        guidanceLinesNode = SCNNode()
        rootNode.addChildNode(guidanceLinesNode)

        guidancePathNode = SCNNode()
        rootNode.addChildNode(guidancePathNode)

        guidanceIndicatorNode = SCNNode()
        rootNode.addChildNode(guidanceIndicatorNode)

        lookaheadNode = SCNNode()
        rootNode.addChildNode(lookaheadNode)

        headingErrorNode = SCNNode()
        rootNode.addChildNode(headingErrorNode)

        coverageNode = SCNNode()
        rootNode.addChildNode(coverageNode)

        trackVectorNode = SCNNode()
        rootNode.addChildNode(trackVectorNode)

        debugNode = SCNNode()
        rootNode.addChildNode(debugNode)

        boundaryNode = SCNNode()
        rootNode.addChildNode(boundaryNode)
    }

    // MARK: - Vehicle

    private func setupVehicle() {
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: 0, y: 3.2))
        trianglePath.addLine(to: CGPoint(x: -1.9, y: -1.6))
        trianglePath.addLine(to: CGPoint(x: 1.9, y: -1.6))
        trianglePath.close()

        let shape = SCNShape(path: trianglePath, extrusionDepth: 0.5)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.96, green: 0.7, blue: 0.3, alpha: 1)
        material.emission.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.4)
        material.lightingModel = .physicallyBased
        shape.materials = [material]

        vehicleNode = SCNNode(geometry: shape)
        vehicleNode.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        vehicleNode.position = SCNVector3(x: 0, y: 0.6, z: 0)

        let axleGeometry = SCNBox(width: 3.4, height: 0.08, length: 0.2, chamferRadius: 0.04)
        let axleMaterial = SCNMaterial()
        axleMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        axleGeometry.materials = [axleMaterial]
        rearAxleMarkerNode = SCNNode(geometry: axleGeometry)
        rearAxleMarkerNode.position = SCNVector3(x: 0, y: -0.25, z: -1.6)
        vehicleNode.addChildNode(rearAxleMarkerNode)

        let tailGeometry = SCNBox(width: 0.12, height: 0.08, length: 8.0, chamferRadius: 0.04)
        let tailMaterial = SCNMaterial()
        tailMaterial.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.6)
        tailMaterial.emission.contents = UIColor.systemTeal.withAlphaComponent(0.3)
        tailGeometry.materials = [tailMaterial]
        headingTailNode = SCNNode(geometry: tailGeometry)
        headingTailNode.position = SCNVector3(x: 0, y: -0.2, z: -4.5)
        vehicleNode.addChildNode(headingTailNode)

        rootNode.addChildNode(vehicleNode)
    }

    // MARK: - Implement T-Bar

    private func setupImplement() {
        implementNode = SCNNode()
        implementNode.position = SCNVector3(x: 0, y: 0.25, z: 0)

        let implementMaterial = SCNMaterial()
        implementMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 1)
        implementMaterial.emission.contents = UIColor(red: 0.1, green: 0.4, blue: 0.3, alpha: 0.35)

        let frameGeometry = SCNBox(width: 6.0, height: 0.12, length: 1.0, chamferRadius: 0.05)
        frameGeometry.materials = [implementMaterial]
        implementFrameNode = SCNNode(geometry: frameGeometry)
        implementFrameNode.position = SCNVector3(x: 0, y: 0, z: -3.0)

        let connectorGeometry = SCNBox(width: 0.1, height: 0.08, length: 3.0, chamferRadius: 0.04)
        let connectorMaterial = SCNMaterial()
        connectorMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
        connectorGeometry.materials = [connectorMaterial]
        implementConnectorNode = SCNNode(geometry: connectorGeometry)
        implementConnectorNode.position = SCNVector3(x: 0, y: 0, z: -1.5)

        implementCorNode = makeMarkerNode(radius: 0.18, color: UIColor.systemTeal.withAlphaComponent(0.9), ring: true)
        implementCorNode.position = SCNVector3(x: 0, y: 0.12, z: -3.0)

        hitchMarkerNode = makeMarkerNode(radius: 0.2, color: UIColor.systemYellow.withAlphaComponent(0.9), ring: true)
        hitchMarkerNode.position = SCNVector3(x: 0, y: 0.12, z: 0)

        implementNode.addChildNode(implementConnectorNode)
        implementNode.addChildNode(implementFrameNode)
        implementNode.addChildNode(implementCorNode)
        rootNode.addChildNode(implementNode)
        rootNode.addChildNode(hitchMarkerNode)
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 55
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 1000

        cameraNode.position = SCNVector3(x: 0, y: 18, z: -28)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))

        rootNode.addChildNode(cameraNode)
    }

    // MARK: - Tile Management

    func updateTiles(centerX: Double, centerZ: Double, renderDistance: Double) {
        let desiredDetail = gridDetail(for: currentZoomScale)
        if desiredDetail != currentGridDetail && currentBackgroundMode == .checkerboard {
            currentGridDetail = desiredDetail
            reloadTiles()
        }

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
        let shouldRefresh = key != lastGuidanceCenterKey || activeLine != lastGuidanceLineIndex
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
        let shouldRefresh = key != lastCoverageCenterKey || generation != lastCoverageGeneration
        if shouldRefresh {
            lastCoverageCenterKey = key
            lastCoverageGeneration = generation
        }
        return shouldRefresh
    }

    private func loadTile(x: Int, z: Int) {
        let key = "\(x)_\(z)"

        let tileGeometry = SCNPlane(width: tileSize, height: tileSize)
        tileGeometry.materials = [currentTileMaterial()]

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

    private func reloadTiles() {
        let keys = Array(loadedTiles.keys)
        for key in keys {
            unloadTile(key: key)
        }
    }

    private func currentTileMaterial() -> SCNMaterial {
        switch currentBackgroundMode {
        case .checkerboard:
            return currentGridDetail == .fine ? gridFineMaterial : gridCoarseMaterial
        case .satellite:
            return satelliteMaterial
        }
    }

    private func gridDetail(for zoom: Float) -> GridDetail {
        zoom > 80 ? .coarse : .fine
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
            let lineGeometry = SCNBox(width: 0.18, height: 0.05, length: lineLength, chamferRadius: 0)

            let lineMaterial = SCNMaterial()
            lineMaterial.diffuse.contents = line.isActive
                ? UIColor.systemTeal.withAlphaComponent(0.4)
                : UIColor.white.withAlphaComponent(0.15)
            lineMaterial.emission.contents = line.isActive
                ? UIColor.systemTeal.withAlphaComponent(0.2)
                : UIColor.clear
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
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.35
        switch mode {
        case .perspective3D:
            cameraNode.camera?.usesOrthographicProjection = false
            cameraNode.camera?.fieldOfView = 55
        case .topDown2D:
            cameraNode.camera?.usesOrthographicProjection = true
            cameraNode.camera?.orthographicScale = 60
        }
        SCNTransaction.commit()
    }

    func updateBackgroundMode(_ mode: BackgroundMode) {
        currentBackgroundMode = mode
        // Reload all tiles with new material
        reloadTiles()
        // Tiles will be reloaded on next update
    }

    func updateVehicle(x: Float, z: Float, heading: Float) {
        vehicleNode.position = SCNVector3(x: x, y: 0.5, z: z)
        // Triangle tip points +Y in local space, rotated to lay flat on XZ plane
        // Y rotation matches camera so vehicle always points "up" on screen
        vehicleNode.eulerAngles = SCNVector3(x: -.pi / 2, y: heading + .pi, z: 0)
        lastVehiclePosition = SCNVector3(x: x, y: 0.1, z: z)
        lastVehicleHeading = heading
    }

    func updateImplement(
        workPointX: Float,
        workPointZ: Float,
        workPointHeading: Float,
        hitchX: Float,
        hitchZ: Float,
        implementWidth: Float,
        corX: Float,
        corZ: Float,
        showDebug: Bool
    ) {
        // Implement visualization:
        // - Connector from hitch to implement
        // - Implement frame at work point
        // - COR marker on implement

        let dx = workPointX - hitchX
        let dz = workPointZ - hitchZ
        let lineLength = sqrt(dx * dx + dz * dz)

        if let connectorGeometry = implementConnectorNode.geometry as? SCNBox {
            let newLine = SCNBox(width: 0.1, height: 0.08, length: CGFloat(max(0.5, lineLength)), chamferRadius: 0.04)
            newLine.materials = connectorGeometry.materials
            implementConnectorNode.geometry = newLine
        }

        if let frameGeometry = implementFrameNode.geometry as? SCNBox {
            let newFrame = SCNBox(width: CGFloat(implementWidth), height: 0.12, length: 1.0, chamferRadius: 0.05)
            newFrame.materials = frameGeometry.materials
            implementFrameNode.geometry = newFrame
        }

        implementNode.position = SCNVector3(x: hitchX, y: 0.25, z: hitchZ)
        implementNode.eulerAngles = SCNVector3(x: 0, y: -workPointHeading, z: 0)

        implementConnectorNode.position = SCNVector3(x: 0, y: 0, z: -lineLength / 2)
        implementFrameNode.position = SCNVector3(x: 0, y: 0, z: -lineLength)
        let corDx = corX - hitchX
        let corDz = corZ - hitchZ
        let corDistance = sqrt(corDx * corDx + corDz * corDz)
        implementCorNode.position = SCNVector3(x: 0, y: 0.12, z: -corDistance)

        hitchMarkerNode.position = SCNVector3(x: hitchX, y: 0.12, z: hitchZ)

        updateDebugMarkers(
            rearAxle: lastVehiclePosition,
            hitch: SCNVector3(x: hitchX, y: 0.1, z: hitchZ),
            cor: SCNVector3(x: corX, y: 0.1, z: corZ),
            implementCenter: SCNVector3(x: workPointX, y: 0.1, z: workPointZ),
            implementWidth: implementWidth,
            implementHeading: workPointHeading,
            showDebug: showDebug
        )
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
        predictionTime: Float,
        showTail: Bool
    ) {
        trackVectorNode.isHidden = !showTail
        guard showTail else { return }
        let speedScale = max(4.0, min(12.0, speed * 2.5))
        if let tailGeometry = headingTailNode.geometry as? SCNBox {
            let newTail = SCNBox(width: 0.12, height: 0.08, length: CGFloat(speedScale), chamferRadius: 0.04)
            newTail.materials = tailGeometry.materials
            headingTailNode.geometry = newTail
        }
        headingTailNode.position = SCNVector3(x: 0, y: -0.2, z: -Float(speedScale / 2 + 1.2))
    }

    func updateGuidanceVisualization(
        referenceX: Float,
        referenceZ: Float,
        pathHeading: Float,
        crossTrackError: Float,
        lookaheadDistance: Float,
        headingError: Float,
        confidence: GuidanceConfidence
    ) {
        guidancePathNode.childNodes.forEach { $0.removeFromParentNode() }
        guidanceIndicatorNode.childNodes.forEach { $0.removeFromParentNode() }
        lookaheadNode.childNodes.forEach { $0.removeFromParentNode() }
        headingErrorNode.childNodes.forEach { $0.removeFromParentNode() }

        let forwardX = sin(pathHeading)
        let forwardZ = cos(pathHeading)
        let rightX = cos(pathHeading)
        let rightZ = -sin(pathHeading)

        let pathX = referenceX - rightX * crossTrackError
        let pathZ = referenceZ - rightZ * crossTrackError

        let lineLength: Float = 240
        let pathGeometry = SCNBox(width: 0.18, height: 0.05, length: CGFloat(lineLength), chamferRadius: 0.02)
        let pathMaterial = SCNMaterial()
        let pathColor = color(for: confidence)
        pathMaterial.diffuse.contents = pathColor.withAlphaComponent(0.8)
        pathMaterial.emission.contents = pathColor.withAlphaComponent(0.3)
        pathGeometry.materials = [pathMaterial]
        let pathNode = SCNNode(geometry: pathGeometry)
        pathNode.position = SCNVector3(x: pathX, y: 0.12, z: pathZ)
        pathNode.eulerAngles = SCNVector3(x: 0, y: -pathHeading, z: 0)
        guidancePathNode.addChildNode(pathNode)

        let lookaheadX = pathX + forwardX * lookaheadDistance
        let lookaheadZ = pathZ + forwardZ * lookaheadDistance
        let lookaheadMarker = makeMarkerNode(radius: 0.22, color: UIColor.systemTeal.withAlphaComponent(0.9), ring: true)
        lookaheadMarker.position = SCNVector3(x: lookaheadX, y: 0.14, z: lookaheadZ)
        lookaheadNode.addChildNode(lookaheadMarker)

        let errorLength = abs(crossTrackError)
        if errorLength > 0.05 {
            let errorGeometry = SCNBox(width: 0.08, height: 0.05, length: CGFloat(errorLength), chamferRadius: 0.02)
            let errorMaterial = SCNMaterial()
            errorMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            errorGeometry.materials = [errorMaterial]
            let errorNode = SCNNode(geometry: errorGeometry)
            errorNode.position = SCNVector3(
                x: (referenceX + pathX) / 2,
                y: 0.12,
                z: (referenceZ + pathZ) / 2
            )
            let errorAngle = atan2(rightX, rightZ)
            errorNode.eulerAngles = SCNVector3(x: 0, y: -errorAngle, z: 0)
            guidanceIndicatorNode.addChildNode(errorNode)
        }

        let clampedHeadingError = max(-.pi / 3, min(.pi / 3, headingError))
        if abs(clampedHeadingError) > 0.01 {
            let arcPath = UIBezierPath(
                arcCenter: CGPoint.zero,
                radius: 2.4,
                startAngle: 0,
                endAngle: CGFloat(clampedHeadingError),
                clockwise: clampedHeadingError > 0
            )
            let arcShape = SCNShape(path: arcPath, extrusionDepth: 0.05)
            let arcMaterial = SCNMaterial()
            arcMaterial.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.7)
            arcShape.materials = [arcMaterial]
            let arcNode = SCNNode(geometry: arcShape)
            arcNode.position = SCNVector3(x: referenceX, y: 0.12, z: referenceZ)
            arcNode.eulerAngles = SCNVector3(x: -.pi / 2, y: -pathHeading, z: 0)
            headingErrorNode.addChildNode(arcNode)
        }
    }

    func updateCamera(
        vehicleX: Float,
        vehicleZ: Float,
        heading: Float,
        mode: ViewMode,
        headingMode: HeadingMode = .northUp,
        isFreeCamera: Bool,
        freeCameraCenterX: Float,
        freeCameraCenterZ: Float,
        freeCameraHeading: Float,
        zoom: Float,
        cameraDistance: Float,
        cameraHeight: Float
    ) {
        // Determine effective heading for camera rotation
        // In heading-up mode, camera rotates with vehicle so vehicle always points up
        // In north-up mode, camera stays fixed (north is up)
        let effectiveHeading = headingMode == .headingUp ? heading : 0

        switch mode {
        case .perspective3D:
            // Camera behind vehicle, looking forward along heading
            let tiltAngle: Float = .pi / 9  // How much camera looks down

            // In heading-up mode, camera follows heading; in north-up, always behind
            let cameraHeading = headingMode == .headingUp ? heading : heading

            // Position camera behind vehicle (opposite of heading direction)
            let focusX = isFreeCamera ? freeCameraCenterX : vehicleX
            let focusZ = isFreeCamera ? freeCameraCenterZ : vehicleZ
            let cameraX = focusX - sin(cameraHeading) * cameraDistance
            let cameraZ = focusZ - cos(cameraHeading) * cameraDistance

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
            let headingOffset = isFreeCamera ? freeCameraHeading : 0
            cameraNode.eulerAngles = SCNVector3(x: -tiltAngle, y: cameraHeading + .pi + headingOffset, z: 0)

        case .topDown2D:
            // Camera directly above vehicle
            let focusX = isFreeCamera ? freeCameraCenterX : vehicleX
            let focusZ = isFreeCamera ? freeCameraCenterZ : vehicleZ
            let currentPos = cameraNode.position
            let targetPos = SCNVector3(x: focusX, y: zoom, z: focusZ)
            let smoothing: Float = 0.2
            cameraNode.position = SCNVector3(
                x: currentPos.x + (targetPos.x - currentPos.x) * smoothing,
                y: currentPos.y + (targetPos.y - currentPos.y) * smoothing,
                z: currentPos.z + (targetPos.z - currentPos.z) * smoothing
            )
            cameraNode.camera?.orthographicScale = Double(zoom)
            // X: -90° to look straight down
            // Y: rotate based on heading mode
            //    heading-up: rotate so vehicle heading points to top of screen
            //    north-up: keep north at top (Y = 0)
            // Z: 0 (no roll)
            let headingOffset = isFreeCamera ? freeCameraHeading : 0
            cameraNode.eulerAngles = SCNVector3(x: -.pi / 2, y: effectiveHeading + .pi + headingOffset, z: 0)
        }
        currentZoomScale = mode == .topDown2D ? zoom : cameraDistance
    }

    func highlightActiveLine(index: Int) {
        // Lines are recreated each frame, so this is handled in updateGuidanceLines
    }

    private func updateDebugMarkers(
        rearAxle: SCNVector3,
        hitch: SCNVector3,
        cor: SCNVector3,
        implementCenter: SCNVector3,
        implementWidth: Float,
        implementHeading: Float,
        showDebug: Bool
    ) {
        debugNode.childNodes.forEach { $0.removeFromParentNode() }
        guard showDebug else { return }

        let rearAxleMarker = makeMarkerNode(radius: 0.16, color: UIColor.white.withAlphaComponent(0.7), ring: false)
        rearAxleMarker.position = rearAxle
        debugNode.addChildNode(rearAxleMarker)

        let hitchMarker = makeMarkerNode(radius: 0.12, color: UIColor.systemYellow.withAlphaComponent(0.6), ring: false)
        hitchMarker.position = hitch
        debugNode.addChildNode(hitchMarker)

        let corMarker = makeMarkerNode(radius: 0.12, color: UIColor.systemTeal.withAlphaComponent(0.6), ring: false)
        corMarker.position = cor
        debugNode.addChildNode(corMarker)

        let halfWidth = implementWidth / 2
        let forwardX = sin(implementHeading)
        let forwardZ = cos(implementHeading)
        let rightX = cos(implementHeading)
        let rightZ = -sin(implementHeading)
        let cornerOffset = 0.5

        let corners = [
            SCNVector3(
                x: implementCenter.x + rightX * halfWidth + forwardX * cornerOffset,
                y: 0.1,
                z: implementCenter.z + rightZ * halfWidth + forwardZ * cornerOffset
            ),
            SCNVector3(
                x: implementCenter.x - rightX * halfWidth + forwardX * cornerOffset,
                y: 0.1,
                z: implementCenter.z - rightZ * halfWidth + forwardZ * cornerOffset
            ),
            SCNVector3(
                x: implementCenter.x + rightX * halfWidth - forwardX * cornerOffset,
                y: 0.1,
                z: implementCenter.z + rightZ * halfWidth - forwardZ * cornerOffset
            ),
            SCNVector3(
                x: implementCenter.x - rightX * halfWidth - forwardX * cornerOffset,
                y: 0.1,
                z: implementCenter.z - rightZ * halfWidth - forwardZ * cornerOffset
            )
        ]

        for corner in corners {
            let marker = makeMarkerNode(radius: 0.08, color: UIColor.white.withAlphaComponent(0.5), ring: false)
            marker.position = corner
            debugNode.addChildNode(marker)
        }

        let axisLength: Float = 1.2
        let axisGeometry = SCNBox(width: 0.05, height: 0.05, length: CGFloat(axisLength), chamferRadius: 0.02)
        let axisMaterial = SCNMaterial()
        axisMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
        axisGeometry.materials = [axisMaterial]
        let axisNode = SCNNode(geometry: axisGeometry)
        axisNode.position = rearAxle
        axisNode.eulerAngles = SCNVector3(x: 0, y: -lastVehicleHeading, z: 0)
        debugNode.addChildNode(axisNode)
    }

    private func makeMarkerNode(radius: CGFloat, color: UIColor, ring: Bool) -> SCNNode {
        let dotGeometry = SCNCylinder(radius: radius, height: 0.06)
        let dotMaterial = SCNMaterial()
        dotMaterial.diffuse.contents = color
        dotGeometry.materials = [dotMaterial]
        let dotNode = SCNNode(geometry: dotGeometry)
        dotNode.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)

        if ring {
            let ringGeometry = SCNTorus(ringRadius: radius * 1.6, pipeRadius: radius * 0.18)
            let ringMaterial = SCNMaterial()
            ringMaterial.diffuse.contents = color.withAlphaComponent(0.5)
            ringGeometry.materials = [ringMaterial]
            let ringNode = SCNNode(geometry: ringGeometry)
            ringNode.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)
            dotNode.addChildNode(ringNode)
        }

        return dotNode
    }

    private func color(for confidence: GuidanceConfidence) -> UIColor {
        switch confidence {
        case .good:
            return UIColor.systemTeal
        case .degraded:
            return UIColor.systemOrange
        case .invalid:
            return UIColor.systemGray
        }
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
