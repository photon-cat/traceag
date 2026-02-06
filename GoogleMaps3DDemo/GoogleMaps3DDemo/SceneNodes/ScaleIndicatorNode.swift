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

/// Scale indicator bar that updates with zoom level
final class ScaleIndicatorNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var barColor: UIColor = GuidanceSceneColors.scaleIndicator
        var barHeight: Float = GuidanceDimensions.scaleBarHeight
        var defaultWidth: Float = GuidanceDimensions.scaleBarWidth
    }

    // MARK: - Child Nodes

    private var barNode: SCNNode!
    private var leftCapNode: SCNNode!
    private var rightCapNode: SCNNode!

    // MARK: - Properties

    private var configuration: Configuration
    private var currentWidthMeters: Float = 10.0

    /// Current scale label (e.g., "10 m")
    var scaleLabel: String {
        if currentWidthMeters >= 1000 {
            return String(format: "%.0f km", currentWidthMeters / 1000)
        } else if currentWidthMeters >= 1 {
            return String(format: "%.0f m", currentWidthMeters)
        } else {
            return String(format: "%.0f cm", currentWidthMeters * 100)
        }
    }

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.currentWidthMeters = configuration.defaultWidth
        super.init()
        name = "ScaleIndicator"
        setupGeometry()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupGeometry()
    }

    // MARK: - Setup

    private func setupGeometry() {
        let material = SCNMaterial()
        material.diffuse.contents = configuration.barColor
        material.emission.contents = configuration.barColor.withAlphaComponent(0.5)

        // Main horizontal bar
        let barGeometry = SCNBox(
            width: CGFloat(currentWidthMeters),
            height: CGFloat(configuration.barHeight * 0.3),
            length: CGFloat(configuration.barHeight),
            chamferRadius: 0
        )
        barGeometry.materials = [material]

        barNode = SCNNode(geometry: barGeometry)
        barNode.position = SCNVector3(x: 0, y: 0.5, z: 0)
        addChildNode(barNode)

        // Left end cap (vertical tick)
        let capGeometry = SCNBox(
            width: CGFloat(configuration.barHeight * 0.3),
            height: CGFloat(configuration.barHeight),
            length: CGFloat(configuration.barHeight),
            chamferRadius: 0
        )
        capGeometry.materials = [material]

        leftCapNode = SCNNode(geometry: capGeometry)
        leftCapNode.position = SCNVector3(x: -currentWidthMeters / 2, y: 0.5, z: 0)
        addChildNode(leftCapNode)

        rightCapNode = SCNNode(geometry: capGeometry)
        rightCapNode.position = SCNVector3(x: currentWidthMeters / 2, y: 0.5, z: 0)
        addChildNode(rightCapNode)
    }

    // MARK: - Update Methods

    /// Update scale based on camera/zoom level
    func updateScale(cameraHeight: Float, viewportWidthMeters: Float) {
        // Choose a nice round number for the scale
        let targetWidth = viewportWidthMeters * 0.15  // ~15% of viewport
        let niceWidth = niceRoundNumber(targetWidth)

        if abs(niceWidth - currentWidthMeters) > 0.01 {
            currentWidthMeters = niceWidth
            updateBarWidth()
        }
    }

    private func niceRoundNumber(_ value: Float) -> Float {
        // Find a nice round number close to value
        let niceValues: [Float] = [
            0.1, 0.2, 0.5,
            1, 2, 5,
            10, 20, 50,
            100, 200, 500,
            1000, 2000, 5000
        ]

        var closest = niceValues[0]
        var closestDiff = abs(value - closest)

        for nice in niceValues {
            let diff = abs(value - nice)
            if diff < closestDiff {
                closest = nice
                closestDiff = diff
            }
        }

        return closest
    }

    private func updateBarWidth() {
        // Update bar geometry
        if let barGeometry = barNode.geometry as? SCNBox {
            let newBar = SCNBox(
                width: CGFloat(currentWidthMeters),
                height: barGeometry.height,
                length: barGeometry.length,
                chamferRadius: 0
            )
            newBar.materials = barGeometry.materials
            barNode.geometry = newBar
        }

        // Update cap positions
        leftCapNode.position = SCNVector3(x: -currentWidthMeters / 2, y: 0.5, z: 0)
        rightCapNode.position = SCNVector3(x: currentWidthMeters / 2, y: 0.5, z: 0)
    }

    /// Position the scale indicator in screen space (called from scene update)
    func updateScreenPosition(cameraNode: SCNNode, offsetX: Float, offsetZ: Float) {
        // Position relative to camera but fixed on ground plane
        let cameraPos = cameraNode.position
        self.position = SCNVector3(
            x: cameraPos.x + offsetX,
            y: 0.1,
            z: cameraPos.z + offsetZ
        )

        // Keep bar horizontal regardless of camera rotation
        self.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        let material = SCNMaterial()
        material.diffuse.contents = config.barColor
        material.emission.contents = config.barColor.withAlphaComponent(0.5)

        barNode.geometry?.firstMaterial = material
        leftCapNode.geometry?.firstMaterial = material
        rightCapNode.geometry?.firstMaterial = material
    }
}
