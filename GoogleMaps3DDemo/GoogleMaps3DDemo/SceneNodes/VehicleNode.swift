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

/// Vehicle nav cursor glyph with flat rear axle edge
final class VehicleNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var bodyColor: UIColor = GuidanceSceneColors.vehicle
        var rearAxleColor: UIColor = GuidanceSceneColors.rearAxle
        var velocityTailColor: UIColor = GuidanceSceneColors.velocityTail
        var showVelocityTail: Bool = true
        var vehicleLength: Float = GuidanceDimensions.vehicleLength
        var vehicleWidth: Float = GuidanceDimensions.vehicleWidth
    }

    // MARK: - Child Nodes

    private var bodyNode: SCNNode!
    private var rearAxleMarkerNode: SCNNode!
    private var velocityTailNode: SCNNode?

    // MARK: - Properties

    private var configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init()
        name = "Vehicle"
        setupGeometry()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupGeometry()
    }

    // MARK: - Setup

    private func setupGeometry() {
        // Forward-pointing triangular arrowhead nav cursor
        // Tip at front, flat edge at rear representing rear axle
        let path = UIBezierPath()

        let tipY = configuration.vehicleLength * 0.6      // Tip extends forward
        let rearY = -configuration.vehicleLength * 0.4    // Flat rear
        let halfWidth = configuration.vehicleWidth / 2

        path.move(to: CGPoint(x: 0, y: CGFloat(tipY)))           // Tip (forward)
        path.addLine(to: CGPoint(x: CGFloat(-halfWidth), y: CGFloat(rearY)))  // Left rear
        path.addLine(to: CGPoint(x: CGFloat(halfWidth), y: CGFloat(rearY)))   // Right rear
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0.4)

        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = configuration.bodyColor
        bodyMaterial.emission.contents = configuration.bodyColor.withAlphaComponent(0.4)
        bodyMaterial.isDoubleSided = true
        shape.materials = [bodyMaterial]

        bodyNode = SCNNode(geometry: shape)
        bodyNode.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        bodyNode.position = SCNVector3(x: 0, y: 0.3, z: 0)
        addChildNode(bodyNode)

        // Rear axle marker line (emphasizes the flat rear edge)
        let axleWidth = configuration.vehicleWidth + 0.4  // Slightly wider than body
        let axleGeometry = SCNBox(
            width: CGFloat(axleWidth),
            height: CGFloat(GuidanceDimensions.rearAxleThickness),
            length: 0.2,
            chamferRadius: 0
        )

        let axleMaterial = SCNMaterial()
        axleMaterial.diffuse.contents = configuration.rearAxleColor
        axleMaterial.emission.contents = configuration.rearAxleColor.withAlphaComponent(0.6)
        axleGeometry.materials = [axleMaterial]

        rearAxleMarkerNode = SCNNode(geometry: axleGeometry)
        // Position at the rear of the vehicle (the flat edge)
        rearAxleMarkerNode.position = SCNVector3(
            x: 0,
            y: 0.35,
            z: -configuration.vehicleLength * 0.4  // At rear axle position
        )
        addChildNode(rearAxleMarkerNode)

        // Velocity tail (optional)
        if configuration.showVelocityTail {
            setupVelocityTail()
        }
    }

    private func setupVelocityTail() {
        // Thin line extending behind vehicle showing direction
        let tailLength: Float = 2.0
        let tailGeometry = SCNBox(width: 0.1, height: 0.08, length: CGFloat(tailLength), chamferRadius: 0)

        let tailMaterial = SCNMaterial()
        tailMaterial.diffuse.contents = configuration.velocityTailColor
        tailMaterial.emission.contents = configuration.velocityTailColor.withAlphaComponent(0.3)
        tailGeometry.materials = [tailMaterial]

        velocityTailNode = SCNNode(geometry: tailGeometry)
        velocityTailNode?.position = SCNVector3(
            x: 0,
            y: 0.25,
            z: -configuration.vehicleLength * 0.4 - tailLength / 2 - 0.3
        )
        velocityTailNode?.isHidden = true

        if let node = velocityTailNode {
            addChildNode(node)
        }
    }

    // MARK: - Update Methods

    /// Update vehicle position and heading
    func update(x: Float, z: Float, heading: Float) {
        self.position = SCNVector3(x: x, y: 0, z: z)
        // Rotate so vehicle points in heading direction
        // heading = 0 means north (positive Z), π/2 means east (positive X)
        self.eulerAngles = SCNVector3(x: 0, y: heading + .pi, z: 0)
    }

    /// Update velocity tail visibility and length based on speed
    func updateVelocityTail(speed: Float, yawRate: Float) {
        guard configuration.showVelocityTail else {
            velocityTailNode?.isHidden = true
            return
        }

        // Show tail only when moving
        let showTail = speed > 0.5
        velocityTailNode?.isHidden = !showTail

        if showTail {
            // Tail length based on speed (longer = faster)
            let tailLength = min(speed * 0.5, 5.0)

            if let geometry = velocityTailNode?.geometry as? SCNBox {
                let newGeometry = SCNBox(
                    width: geometry.width,
                    height: geometry.height,
                    length: CGFloat(tailLength),
                    chamferRadius: 0
                )
                newGeometry.materials = geometry.materials
                velocityTailNode?.geometry = newGeometry
            }

            velocityTailNode?.position = SCNVector3(
                x: 0,
                y: 0.25,
                z: -configuration.vehicleLength * 0.4 - tailLength / 2 - 0.3
            )
        }
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        // Update body color
        if let shape = bodyNode.geometry as? SCNShape,
           let material = shape.firstMaterial {
            material.diffuse.contents = config.bodyColor
            material.emission.contents = config.bodyColor.withAlphaComponent(0.4)
        }

        // Update axle color
        if let material = rearAxleMarkerNode.geometry?.firstMaterial {
            material.diffuse.contents = config.rearAxleColor
            material.emission.contents = config.rearAxleColor.withAlphaComponent(0.6)
        }

        // Update tail visibility
        velocityTailNode?.isHidden = !config.showVelocityTail
    }
}
