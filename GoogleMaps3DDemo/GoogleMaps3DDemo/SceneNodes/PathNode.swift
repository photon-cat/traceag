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
import CoreGraphics

/// Track vector visualization with desired path, lookahead point, and error indicators
final class PathNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var pathColorGood: UIColor = GuidanceSceneColors.pathGood
        var pathColorDegraded: UIColor = GuidanceSceneColors.pathDegraded
        var pathColorInvalid: UIColor = GuidanceSceneColors.pathInvalid
        var lookaheadColor: UIColor = GuidanceSceneColors.lookahead
        var lateralErrorColor: UIColor = GuidanceSceneColors.lateralError
        var pathWidth: Float = GuidanceDimensions.pathWidth
        var lookaheadRadius: Float = GuidanceDimensions.lookaheadRadius
    }

    // MARK: - Child Nodes

    private var pathLinesNode: SCNNode!
    private var lookaheadMarkerNode: SCNNode!
    private var lateralErrorNode: SCNNode?
    private var headingErrorNode: SCNNode?

    // MARK: - Properties

    private var configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init()
        name = "PathNode"
        setupNodes()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupNodes()
    }

    // MARK: - Setup

    private func setupNodes() {
        pathLinesNode = SCNNode()
        pathLinesNode.name = "PathLines"
        addChildNode(pathLinesNode)

        // Lookahead marker (sphere)
        let lookaheadGeometry = SCNSphere(radius: CGFloat(configuration.lookaheadRadius))
        let lookaheadMaterial = SCNMaterial()
        lookaheadMaterial.diffuse.contents = configuration.lookaheadColor
        lookaheadMaterial.emission.contents = configuration.lookaheadColor.withAlphaComponent(0.8)
        lookaheadGeometry.materials = [lookaheadMaterial]

        lookaheadMarkerNode = SCNNode(geometry: lookaheadGeometry)
        lookaheadMarkerNode.name = "Lookahead"
        lookaheadMarkerNode.isHidden = true
        addChildNode(lookaheadMarkerNode)
    }

    // MARK: - Update Methods

    /// Update the track vector visualization
    func update(data: TrackVectorResult, vehicleX: Float, vehicleZ: Float) {
        updatePathLine(points: data.desiredPath, confidence: data.confidence)
        updateLookaheadMarker(point: data.lookaheadPoint)
        updateLateralErrorIndicator(
            vehicleX: vehicleX,
            vehicleZ: vehicleZ,
            projectedPoint: data.projectedPoint,
            error: data.lateralError
        )
    }

    /// Update with raw data points
    func update(
        pathPoints: [CGPoint],
        lookaheadPoint: CGPoint,
        projectedPoint: CGPoint,
        vehicleX: Float,
        vehicleZ: Float,
        lateralError: Double,
        confidence: Double
    ) {
        updatePathLine(points: pathPoints, confidence: confidence)
        updateLookaheadMarker(point: lookaheadPoint)
        updateLateralErrorIndicator(
            vehicleX: vehicleX,
            vehicleZ: vehicleZ,
            projectedPoint: projectedPoint,
            error: lateralError
        )
    }

    // MARK: - Path Line

    private func updatePathLine(points: [CGPoint], confidence: Double) {
        // Remove old path segments
        pathLinesNode.childNodes.forEach { $0.removeFromParentNode() }

        guard points.count >= 2 else {
            return
        }

        // Determine color based on confidence
        let pathColor = colorForConfidence(confidence)

        // Create line segments
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]

            let dx = Float(end.x - start.x)
            let dz = Float(end.y - start.y)
            let length = sqrt(dx * dx + dz * dz)

            guard length > 0.01 else { continue }

            // Fade alpha along path (brighter near start)
            let progress = Float(i) / Float(points.count - 1)
            let alpha = CGFloat(1.0 - progress * 0.6)

            let segmentGeometry = SCNBox(
                width: CGFloat(configuration.pathWidth),
                height: 0.1,
                length: CGFloat(length),
                chamferRadius: 0
            )

            let segmentMaterial = SCNMaterial()
            segmentMaterial.diffuse.contents = pathColor.withAlphaComponent(alpha)
            segmentMaterial.emission.contents = pathColor.withAlphaComponent(alpha * 0.5)
            segmentGeometry.materials = [segmentMaterial]

            let segmentNode = SCNNode(geometry: segmentGeometry)
            segmentNode.position = SCNVector3(
                x: Float(start.x + end.x) / 2,
                y: 0.15,
                z: Float(start.y + end.y) / 2
            )

            // Rotate to align with segment direction
            let angle = atan2(dx, dz)
            segmentNode.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

            pathLinesNode.addChildNode(segmentNode)
        }
    }

    private func colorForConfidence(_ confidence: Double) -> UIColor {
        if confidence > 0.7 {
            return configuration.pathColorGood
        } else if confidence > 0.4 {
            return configuration.pathColorDegraded
        } else {
            return configuration.pathColorInvalid
        }
    }

    // MARK: - Lookahead Marker

    private func updateLookaheadMarker(point: CGPoint) {
        lookaheadMarkerNode.isHidden = false
        lookaheadMarkerNode.position = SCNVector3(
            x: Float(point.x),
            y: 0.4,
            z: Float(point.y)
        )
    }

    // MARK: - Lateral Error Indicator

    private func updateLateralErrorIndicator(
        vehicleX: Float,
        vehicleZ: Float,
        projectedPoint: CGPoint,
        error: Double
    ) {
        // Remove old indicator
        lateralErrorNode?.removeFromParentNode()

        let absError = abs(error)
        guard absError > 0.05 else { return }  // Don't show for tiny errors

        // Line from vehicle to projected point on path
        let dx = Float(projectedPoint.x) - vehicleX
        let dz = Float(projectedPoint.y) - vehicleZ
        let length = sqrt(dx * dx + dz * dz)

        guard length > 0.05 else { return }

        let lineGeometry = SCNBox(
            width: CGFloat(GuidanceDimensions.errorLineWidth),
            height: 0.08,
            length: CGFloat(length),
            chamferRadius: 0
        )

        // Color based on error magnitude
        let errorColor: UIColor
        if absError < 0.5 {
            errorColor = GuidanceSceneColors.pathGood
        } else if absError < 2.0 {
            errorColor = GuidanceSceneColors.pathDegraded
        } else {
            errorColor = configuration.lateralErrorColor
        }

        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = errorColor
        lineMaterial.emission.contents = errorColor.withAlphaComponent(0.6)
        lineGeometry.materials = [lineMaterial]

        lateralErrorNode = SCNNode(geometry: lineGeometry)
        lateralErrorNode?.position = SCNVector3(
            x: vehicleX + dx / 2,
            y: 0.5,
            z: vehicleZ + dz / 2
        )

        // Rotate to align
        let angle = atan2(dx, dz)
        lateralErrorNode?.eulerAngles = SCNVector3(x: 0, y: -angle, z: 0)

        if let node = lateralErrorNode {
            addChildNode(node)
        }
    }

    // MARK: - Visibility

    func setVisible(_ visible: Bool) {
        isHidden = !visible
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        // Update lookahead marker
        if let material = lookaheadMarkerNode.geometry?.firstMaterial {
            material.diffuse.contents = config.lookaheadColor
            material.emission.contents = config.lookaheadColor.withAlphaComponent(0.8)
        }
    }
}
