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

/// Coverage visualization with semi-transparent fill and overlap detection
final class CoverageNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var fillColor: UIColor = GuidanceSceneColors.coverageFill
        var overlapColor: UIColor = GuidanceSceneColors.coverageOverlap
        var cellHeight: Float = 0.08
        var showOverlap: Bool = true
    }

    // MARK: - Properties

    private var configuration: Configuration
    private var cellSize: Double = 1.0
    private var lastGeneration: Int = -1

    // Cached materials
    private lazy var coverageMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = configuration.fillColor
        material.emission.contents = configuration.fillColor.withAlphaComponent(0.15)
        material.transparency = 0.6
        material.isDoubleSided = true
        return material
    }()

    private lazy var overlapMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = configuration.overlapColor
        material.emission.contents = configuration.overlapColor.withAlphaComponent(0.2)
        material.transparency = 0.5
        material.isDoubleSided = true
        return material
    }()

    // Track overlap for striping effect
    private var cellPassCount: [String: Int] = [:]

    // MARK: - Initialization

    init(configuration: Configuration = Configuration(), cellSize: Double = 1.0) {
        self.configuration = configuration
        self.cellSize = cellSize
        super.init()
        name = "Coverage"
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
    }

    // MARK: - Update Methods

    /// Update coverage visualization
    func update(
        coveredCells: Set<String>,
        centerX: Double,
        centerZ: Double,
        renderDistance: Double,
        generation: Int
    ) {
        // Skip if nothing changed
        guard generation != lastGeneration else { return }
        lastGeneration = generation

        // Clear old coverage
        childNodes.forEach { $0.removeFromParentNode() }

        // Calculate visible range
        let minCol = Int(floor((centerX - renderDistance) / cellSize))
        let maxCol = Int(ceil((centerX + renderDistance) / cellSize))
        let minRow = Int(floor((centerZ - renderDistance) / cellSize))
        let maxRow = Int(ceil((centerZ + renderDistance) / cellSize))

        // Build coverage strips per row for performance
        for row in minRow...maxRow {
            var stripStart: Int? = nil

            for col in minCol...maxCol {
                let key = "\(row)_\(col)"
                let isCovered = coveredCells.contains(key)

                if isCovered {
                    if stripStart == nil {
                        stripStart = col
                    }
                } else if let start = stripStart {
                    addCoverageStrip(row: row, startCol: start, endCol: col - 1)
                    stripStart = nil
                }
            }

            // Handle strip that extends to edge
            if let start = stripStart {
                addCoverageStrip(row: row, startCol: start, endCol: maxCol)
            }
        }
    }

    private func addCoverageStrip(row: Int, startCol: Int, endCol: Int) {
        let width = Double(endCol - startCol + 1) * cellSize

        // Create strip geometry with soft edge appearance
        let geometry = SCNBox(
            width: CGFloat(width),
            height: CGFloat(configuration.cellHeight),
            length: CGFloat(cellSize),
            chamferRadius: CGFloat(configuration.cellHeight * 0.3)
        )

        // Determine if this is overlap (simplified - in real impl would track properly)
        let isOverlap = false  // Would check cellPassCount

        geometry.materials = [isOverlap ? overlapMaterial : coverageMaterial]

        let node = SCNNode(geometry: geometry)
        let centerX = Double(startCol) * cellSize + width / 2
        let centerZ = Double(row) * cellSize + cellSize / 2
        node.position = SCNVector3(
            x: Float(centerX),
            y: configuration.cellHeight / 2 + 0.02,
            z: Float(centerZ)
        )

        addChildNode(node)
    }

    /// Record a new coverage pass (for overlap detection)
    func recordPass(row: Int, col: Int) {
        let key = "\(row)_\(col)"
        cellPassCount[key, default: 0] += 1
    }

    /// Check if a cell has overlap
    func hasOverlap(row: Int, col: Int) -> Bool {
        let key = "\(row)_\(col)"
        return (cellPassCount[key] ?? 0) > 1
    }

    /// Clear all coverage data
    func clearCoverage() {
        childNodes.forEach { $0.removeFromParentNode() }
        cellPassCount.removeAll()
        lastGeneration = -1
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        coverageMaterial.diffuse.contents = config.fillColor
        coverageMaterial.emission.contents = config.fillColor.withAlphaComponent(0.15)

        overlapMaterial.diffuse.contents = config.overlapColor
        overlapMaterial.emission.contents = config.overlapColor.withAlphaComponent(0.2)

        // Force redraw
        lastGeneration = -1
    }
}
