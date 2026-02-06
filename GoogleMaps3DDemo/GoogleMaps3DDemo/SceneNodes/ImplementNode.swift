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

/// Implement visualization with tool frame and center of rotation marker
final class ImplementNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var frameColor: UIColor = GuidanceSceneColors.implement
        var corColor: UIColor = GuidanceSceneColors.implementCOR
        var connectorColor: UIColor = UIColor.white.withAlphaComponent(0.5)
        var defaultWidth: Float = 6.0
        var defaultLength: Float = 1.0
        var showCOR: Bool = true
    }

    // MARK: - Child Nodes

    private var frameNode: SCNNode!
    private var corMarkerNode: SCNNode?
    private var connectorLineNode: SCNNode?

    // MARK: - Properties

    private var configuration: Configuration
    private var currentWidth: Float = 6.0
    private var currentLength: Float = 1.0

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.currentWidth = configuration.defaultWidth
        self.currentLength = configuration.defaultLength
        super.init()
        name = "Implement"
        setupGeometry()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupGeometry()
    }

    // MARK: - Setup

    private func setupGeometry() {
        // Main implement frame (rectangle)
        let frameGeometry = SCNBox(
            width: CGFloat(currentWidth),
            height: 0.2,
            length: CGFloat(currentLength),
            chamferRadius: 0.05
        )

        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = configuration.frameColor
        frameMaterial.emission.contents = configuration.frameColor.withAlphaComponent(0.4)
        frameGeometry.materials = [frameMaterial]

        frameNode = SCNNode(geometry: frameGeometry)
        frameNode.position = SCNVector3(x: 0, y: 0.25, z: 0)
        addChildNode(frameNode)

        // Center of Rotation marker
        if configuration.showCOR {
            setupCORMarker()
        }
    }

    private func setupCORMarker() {
        // COR marker - small crosshair/dot
        let corRadius = GuidanceDimensions.corMarkerRadius

        // Central dot
        let dotGeometry = SCNSphere(radius: CGFloat(corRadius))
        let dotMaterial = SCNMaterial()
        dotMaterial.diffuse.contents = configuration.corColor
        dotMaterial.emission.contents = configuration.corColor.withAlphaComponent(0.8)
        dotGeometry.materials = [dotMaterial]

        corMarkerNode = SCNNode(geometry: dotGeometry)
        corMarkerNode?.position = SCNVector3(x: 0, y: 0.4, z: 0)

        // Add crosshair lines
        let crosshairLength: Float = corRadius * 3
        let crosshairThickness: Float = 0.05

        // Horizontal crosshair
        let hCrosshair = SCNBox(
            width: CGFloat(crosshairLength),
            height: CGFloat(crosshairThickness),
            length: CGFloat(crosshairThickness),
            chamferRadius: 0
        )
        let crosshairMaterial = SCNMaterial()
        crosshairMaterial.diffuse.contents = configuration.corColor
        crosshairMaterial.emission.contents = configuration.corColor.withAlphaComponent(0.6)
        hCrosshair.materials = [crosshairMaterial]

        let hNode = SCNNode(geometry: hCrosshair)
        hNode.position = SCNVector3(x: 0, y: 0.4, z: 0)
        corMarkerNode?.addChildNode(hNode)

        // Vertical crosshair (in Z direction)
        let vCrosshair = SCNBox(
            width: CGFloat(crosshairThickness),
            height: CGFloat(crosshairThickness),
            length: CGFloat(crosshairLength),
            chamferRadius: 0
        )
        vCrosshair.materials = [crosshairMaterial]

        let vNode = SCNNode(geometry: vCrosshair)
        vNode.position = SCNVector3(x: 0, y: 0.4, z: 0)
        corMarkerNode?.addChildNode(vNode)

        if let node = corMarkerNode {
            addChildNode(node)
        }
    }

    // MARK: - Update Methods

    /// Update implement position and orientation
    /// - Parameters:
    ///   - x: X position in world coords
    ///   - z: Z position in world coords
    ///   - heading: Implement heading in radians
    ///   - width: Implement width in meters
    func update(x: Float, z: Float, heading: Float, width: Float) {
        self.position = SCNVector3(x: x, y: 0, z: z)
        self.eulerAngles = SCNVector3(x: 0, y: -heading, z: 0)

        // Update width if changed
        if abs(width - currentWidth) > 0.01 {
            currentWidth = width
            updateFrameGeometry()
        }
    }

    /// Update with full transform including hitch connection
    func update(
        workPointX: Float,
        workPointZ: Float,
        workPointHeading: Float,
        hitchX: Float,
        hitchZ: Float,
        implementWidth: Float
    ) {
        // Position at work point center
        self.position = SCNVector3(x: workPointX, y: 0, z: workPointZ)
        self.eulerAngles = SCNVector3(x: 0, y: -workPointHeading, z: 0)

        // Update width if changed
        if abs(implementWidth - currentWidth) > 0.01 {
            currentWidth = implementWidth
            updateFrameGeometry()
        }

        // Update connector line from hitch to implement
        updateConnectorLine(fromX: hitchX, fromZ: hitchZ, toX: workPointX, toZ: workPointZ)
    }

    private func updateFrameGeometry() {
        let newGeometry = SCNBox(
            width: CGFloat(currentWidth),
            height: 0.2,
            length: CGFloat(currentLength),
            chamferRadius: 0.05
        )
        if let materials = frameNode.geometry?.materials {
            newGeometry.materials = materials
        }
        frameNode.geometry = newGeometry
    }

    private func updateConnectorLine(fromX: Float, fromZ: Float, toX: Float, toZ: Float) {
        // Remove old connector
        connectorLineNode?.removeFromParentNode()

        let dx = toX - fromX
        let dz = toZ - fromZ
        let length = sqrt(dx * dx + dz * dz)

        guard length > 0.1 else { return }

        let lineGeometry = SCNBox(width: 0.08, height: 0.06, length: CGFloat(length), chamferRadius: 0)

        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = configuration.connectorColor
        lineMaterial.emission.contents = configuration.connectorColor.withAlphaComponent(0.2)
        lineGeometry.materials = [lineMaterial]

        connectorLineNode = SCNNode(geometry: lineGeometry)

        // Position at midpoint (in world coords, not local)
        let midX = (fromX + toX) / 2
        let midZ = (fromZ + toZ) / 2
        connectorLineNode?.position = SCNVector3(x: midX - position.x, y: 0.2, z: midZ - position.z)

        // Rotate to align with direction (in local space)
        let angle = atan2(dx, dz)
        connectorLineNode?.eulerAngles = SCNVector3(x: 0, y: -angle + eulerAngles.y, z: 0)

        if let node = connectorLineNode {
            addChildNode(node)
        }
    }

    // MARK: - COR Position

    /// Update the center of rotation marker position relative to implement
    func updateCORPosition(offset: Float) {
        corMarkerNode?.position = SCNVector3(x: 0, y: 0.4, z: offset)
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        // Update frame color
        if let material = frameNode.geometry?.firstMaterial {
            material.diffuse.contents = config.frameColor
            material.emission.contents = config.frameColor.withAlphaComponent(0.4)
        }

        // Update COR visibility
        corMarkerNode?.isHidden = !config.showCOR
    }
}
