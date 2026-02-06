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

/// Hitch point marker with bright dot and ring/halo
final class HitchMarkerNode: SCNNode {

    // MARK: - Configuration

    struct Configuration {
        var markerColor: UIColor = GuidanceSceneColors.hitchMarker
        var haloColor: UIColor = GuidanceSceneColors.hitchHalo
        var markerRadius: Float = GuidanceDimensions.hitchMarkerRadius
        var haloRadius: Float = GuidanceDimensions.hitchHaloRadius
        var showHalo: Bool = true
    }

    // MARK: - Child Nodes

    private var dotNode: SCNNode!
    private var haloNode: SCNNode?
    private var ringNode: SCNNode?

    // MARK: - Properties

    private var configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init()
        name = "HitchMarker"
        setupGeometry()
    }

    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: coder)
        setupGeometry()
    }

    // MARK: - Setup

    private func setupGeometry() {
        // Main dot (sphere)
        let dotGeometry = SCNSphere(radius: CGFloat(configuration.markerRadius))

        let dotMaterial = SCNMaterial()
        dotMaterial.diffuse.contents = configuration.markerColor
        dotMaterial.emission.contents = configuration.markerColor.withAlphaComponent(0.8)
        dotGeometry.materials = [dotMaterial]

        dotNode = SCNNode(geometry: dotGeometry)
        dotNode.position = SCNVector3(x: 0, y: 0.35, z: 0)
        addChildNode(dotNode)

        if configuration.showHalo {
            setupHalo()
            setupRing()
        }
    }

    private func setupHalo() {
        // Outer halo (larger, semi-transparent sphere)
        let haloGeometry = SCNSphere(radius: CGFloat(configuration.haloRadius))

        let haloMaterial = SCNMaterial()
        haloMaterial.diffuse.contents = configuration.haloColor
        haloMaterial.emission.contents = configuration.haloColor.withAlphaComponent(0.3)
        haloMaterial.transparency = 0.4
        haloMaterial.isDoubleSided = true
        haloGeometry.materials = [haloMaterial]

        haloNode = SCNNode(geometry: haloGeometry)
        haloNode?.position = SCNVector3(x: 0, y: 0.35, z: 0)

        if let node = haloNode {
            addChildNode(node)
        }
    }

    private func setupRing() {
        // Ring around the dot (torus)
        let torusGeometry = SCNTorus(
            ringRadius: CGFloat(configuration.haloRadius * 0.8),
            pipeRadius: 0.05
        )

        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = configuration.markerColor
        ringMaterial.emission.contents = configuration.markerColor.withAlphaComponent(0.5)
        torusGeometry.materials = [ringMaterial]

        ringNode = SCNNode(geometry: torusGeometry)
        ringNode?.position = SCNVector3(x: 0, y: 0.35, z: 0)
        ringNode?.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)  // Lay flat

        if let node = ringNode {
            addChildNode(node)
        }
    }

    // MARK: - Update Methods

    /// Update hitch marker position
    func update(x: Float, z: Float) {
        self.position = SCNVector3(x: x, y: 0, z: z)
    }

    /// Animate the halo (subtle pulse effect)
    func startPulseAnimation() {
        guard let halo = haloNode else { return }

        let scaleUp = SCNAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
        let pulse = SCNAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SCNAction.repeatForever(pulse)

        halo.runAction(repeatPulse, forKey: "pulse")
    }

    func stopPulseAnimation() {
        haloNode?.removeAction(forKey: "pulse")
        haloNode?.scale = SCNVector3(1, 1, 1)
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ config: Configuration) {
        self.configuration = config

        // Update dot
        if let material = dotNode.geometry?.firstMaterial {
            material.diffuse.contents = config.markerColor
            material.emission.contents = config.markerColor.withAlphaComponent(0.8)
        }

        // Update halo
        if let material = haloNode?.geometry?.firstMaterial {
            material.diffuse.contents = config.haloColor
            material.emission.contents = config.haloColor.withAlphaComponent(0.3)
        }

        // Update ring
        if let material = ringNode?.geometry?.firstMaterial {
            material.diffuse.contents = config.markerColor
            material.emission.contents = config.markerColor.withAlphaComponent(0.5)
        }

        // Handle halo visibility
        haloNode?.isHidden = !config.showHalo
        ringNode?.isHidden = !config.showHalo
    }
}
