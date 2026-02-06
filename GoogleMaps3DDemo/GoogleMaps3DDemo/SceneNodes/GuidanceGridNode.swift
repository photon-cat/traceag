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

/// Professional guidance grid with dark background and LOD-based line rendering
final class GuidanceGridNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var backgroundColor: UIColor = GuidanceSceneColors.gridBackground
        var majorLineColor: UIColor = GuidanceSceneColors.gridMajor
        var minorLineColor: UIColor = GuidanceSceneColors.gridMinor
        var majorSpacing: Float = GuidanceDimensions.gridMajorSpacing
        var minorSpacing: Float = GuidanceDimensions.gridMinorSpacing
        var majorLineWidth: Float = GuidanceDimensions.gridMajorWidth
        var minorLineWidth: Float = GuidanceDimensions.gridMinorWidth
    }

    // MARK: - LOD

    enum LODLevel: Int {
        case high = 0    // Show 1m and 5m lines
        case medium = 1  // Show 5m lines only
        case low = 2     // Show 10m lines only
    }

    // MARK: - Properties

    private var configuration: Configuration
    private var currentLOD: LODLevel = .high
    private var gridExtent: Float = 200.0
    private var groundPlaneNode: SCNNode?
    private var linesNode: SCNNode?

    // Cached materials
    private lazy var majorLineMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = configuration.majorLineColor
        material.emission.contents = configuration.majorLineColor.withAlphaComponent(0.2)
        material.isDoubleSided = true
        return material
    }()

    private lazy var minorLineMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = configuration.minorLineColor
        material.emission.contents = configuration.minorLineColor.withAlphaComponent(0.1)
        material.isDoubleSided = true
        return material
    }()

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init()
        name = "GuidanceGrid"
        setupGroundPlane()
        rebuildLines()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupGroundPlane()
        rebuildLines()
    }

    // MARK: - Setup

    private func setupGroundPlane() {
        // Large dark ground plane
        let planeSize: CGFloat = 2000.0
        let plane = SCNPlane(width: planeSize, height: planeSize)

        let material = SCNMaterial()
        material.diffuse.contents = configuration.backgroundColor
        material.isDoubleSided = true
        plane.materials = [material]

        groundPlaneNode = SCNNode(geometry: plane)
        groundPlaneNode?.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        groundPlaneNode?.position = SCNVector3(x: 0, y: -0.02, z: 0)

        if let node = groundPlaneNode {
            addChildNode(node)
        }
    }

    // MARK: - LOD Management

    /// Update LOD based on camera height
    func updateLOD(cameraHeight: Float) {
        let newLOD: LODLevel
        if cameraHeight < GuidanceLOD.highDetailThreshold {
            newLOD = .high
        } else if cameraHeight < GuidanceLOD.mediumDetailThreshold {
            newLOD = .medium
        } else {
            newLOD = .low
        }

        if newLOD != currentLOD {
            currentLOD = newLOD
            rebuildLines()
        }
    }

    /// Update grid center position and extent
    func updatePosition(centerX: Float, centerZ: Float, extent: Float) {
        self.position = SCNVector3(x: centerX, y: 0, z: centerZ)

        if abs(extent - gridExtent) > 10 {
            gridExtent = extent
            rebuildLines()
        }
    }

    // MARK: - Line Building

    private func rebuildLines() {
        linesNode?.removeFromParentNode()
        linesNode = SCNNode()
        linesNode?.name = "GridLines"

        switch currentLOD {
        case .high:
            // Show minor (1m) and major (5m) lines
            createLines(spacing: configuration.minorSpacing, material: minorLineMaterial)
            createLines(spacing: configuration.majorSpacing, material: majorLineMaterial)
        case .medium:
            // Show only major (5m) lines
            createLines(spacing: configuration.majorSpacing, material: majorLineMaterial)
        case .low:
            // Show only 10m lines
            createLines(spacing: GuidanceLOD.lowDetailSpacing, material: majorLineMaterial)
        }

        if let node = linesNode {
            addChildNode(node)
        }
    }

    private func createLines(spacing: Float, material: SCNMaterial) {
        let halfExtent = gridExtent / 2
        let lineCount = Int(gridExtent / spacing) + 1
        let startOffset = -halfExtent

        // Determine line width based on spacing
        let lineWidth: Float = spacing <= 1.0 ? configuration.minorLineWidth : configuration.majorLineWidth

        // Create X-direction lines (parallel to X axis)
        for i in 0..<lineCount {
            let z = startOffset + Float(i) * spacing
            let line = createLine(
                from: SCNVector3(x: -halfExtent, y: 0.01, z: z),
                to: SCNVector3(x: halfExtent, y: 0.01, z: z),
                width: lineWidth,
                material: material
            )
            linesNode?.addChildNode(line)
        }

        // Create Z-direction lines (parallel to Z axis)
        for i in 0..<lineCount {
            let x = startOffset + Float(i) * spacing
            let line = createLine(
                from: SCNVector3(x: x, y: 0.01, z: -halfExtent),
                to: SCNVector3(x: x, y: 0.01, z: halfExtent),
                width: lineWidth,
                material: material
            )
            linesNode?.addChildNode(line)
        }
    }

    private func createLine(from start: SCNVector3, to end: SCNVector3, width: Float, material: SCNMaterial) -> SCNNode {
        let dx = end.x - start.x
        let dz = end.z - start.z
        let length = sqrt(dx * dx + dz * dz)

        let box = SCNBox(width: CGFloat(width), height: 0.02, length: CGFloat(length), chamferRadius: 0)
        box.materials = [material]

        let node = SCNNode(geometry: box)
        node.position = SCNVector3(
            x: (start.x + end.x) / 2,
            y: start.y,
            z: (start.z + end.z) / 2
        )

        // Rotate to align with direction
        if abs(dx) > 0.01 {
            // X-direction line, no rotation needed
        } else {
            // Z-direction line
            node.eulerAngles = SCNVector3(x: 0, y: .pi / 2, z: 0)
        }

        return node
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        // Update ground plane color
        if let plane = groundPlaneNode?.geometry as? SCNPlane,
           let material = plane.firstMaterial {
            material.diffuse.contents = config.backgroundColor
        }

        // Rebuild lines with new colors
        majorLineMaterial.diffuse.contents = config.majorLineColor
        majorLineMaterial.emission.contents = config.majorLineColor.withAlphaComponent(0.2)
        minorLineMaterial.diffuse.contents = config.minorLineColor
        minorLineMaterial.emission.contents = config.minorLineColor.withAlphaComponent(0.1)

        rebuildLines()
    }
}
