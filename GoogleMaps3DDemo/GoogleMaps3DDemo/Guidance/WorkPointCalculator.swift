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

import Foundation
import CoreLocation

// MARK: - Position with Heading

/// A 2D position with heading
struct PositionWithHeading {
    var x: Double      // meters, local coordinate
    var z: Double      // meters, local coordinate
    var heading: Double  // radians, 0 = North, clockwise positive

    static let zero = PositionWithHeading(x: 0, z: 0, heading: 0)
}

// MARK: - Work Point Calculator

/// Calculates work point position from GPS antenna position using vehicle geometry
class WorkPointCalculator {

    // MARK: - Properties

    var machineProfile: MachineProfile
    var implementProfile: ImplementProfile

    // State for pivoting implement angle estimation
    private var lastHitchPosition: PositionWithHeading?
    private var estimatedPivotAngle: Double = 0  // radians, relative to tractor heading
    private let pivotAngleSmoothing: Double = 0.1  // Low-pass filter coefficient

    // Exposed hitch position for visualization
    private(set) var currentHitchX: Double = 0
    private(set) var currentHitchZ: Double = 0

    // MARK: - Initialization

    init(machine: MachineProfile, implement: ImplementProfile) {
        self.machineProfile = machine
        self.implementProfile = implement
    }

    // MARK: - Main Calculation

    /// Calculate work point position from antenna position
    /// - Parameters:
    ///   - antennaX: Antenna X position in local coordinates (meters)
    ///   - antennaZ: Antenna Z position in local coordinates (meters)
    ///   - tractorHeading: Tractor heading in radians (0 = North, clockwise positive)
    ///   - steerAngle: Current steering angle in radians (optional, for pivot prediction)
    ///   - deltaTime: Time since last update (for pivot angle estimation)
    /// - Returns: Work point position with heading
    func calculateWorkPoint(
        antennaX: Double,
        antennaZ: Double,
        tractorHeading: Double,
        steerAngle: Double? = nil,
        deltaTime: Double = 0.016
    ) -> PositionWithHeading {

        // Step 1: Antenna → Rear Axle Center
        // P_axle = P_antenna + R(θ_tractor) · d_antenna_offset
        let rearAxle = calculateRearAxleFromAntenna(
            antennaX: antennaX,
            antennaZ: antennaZ,
            tractorHeading: tractorHeading
        )

        // Step 2: Rear Axle → Hitch Point
        // P_hitch = P_axle + R(θ_tractor) · d_hitch_offset
        let hitch = calculateHitchFromRearAxle(
            rearAxle: rearAxle,
            tractorHeading: tractorHeading
        )

        // Step 3: Estimate Hitch Yaw (for pivoting implements)
        let hitchHeading: Double
        if implementProfile.isPivoting {
            // θ_hitch = θ_tractor + Δθ_pivot
            let pivotAngle = estimatePivotAngle(
                currentHitch: hitch,
                tractorHeading: tractorHeading,
                steerAngle: steerAngle,
                deltaTime: deltaTime
            )
            hitchHeading = tractorHeading + pivotAngle
        } else {
            // Non-pivoting: implement follows tractor heading
            hitchHeading = tractorHeading
        }

        // Step 4: Hitch → Work Point
        // P_work = P_hitch + R(θ_hitch) · d_work_offset
        let workPoint = calculateWorkPointFromHitch(
            hitch: hitch,
            hitchHeading: hitchHeading
        )

        // Update state for next iteration
        lastHitchPosition = PositionWithHeading(x: hitch.x, z: hitch.z, heading: hitchHeading)

        // Store current hitch position for external access (visualization)
        currentHitchX = hitch.x
        currentHitchZ = hitch.z

        return workPoint
    }

    // MARK: - Step 1: Antenna to Rear Axle

    private func calculateRearAxleFromAntenna(
        antennaX: Double,
        antennaZ: Double,
        tractorHeading: Double
    ) -> (x: Double, z: Double) {
        // Antenna offset is defined as:
        // - longitudinal: positive = forward of rear axle
        // - lateral: positive = right of centerline

        // We need to go FROM antenna TO rear axle, so negate the offsets
        let longOffset = -machineProfile.antennaLongOffset  // behind antenna
        let latOffset = -machineProfile.antennaLateralOffset  // opposite side

        // Rotate offset by tractor heading
        // In our coordinate system: X = East, Z = North
        // Heading 0 = North, clockwise positive
        // Forward direction: (sin(heading), cos(heading))
        // Right direction: (cos(heading), -sin(heading))
        let forwardX = sin(tractorHeading)
        let forwardZ = cos(tractorHeading)
        let rightX = cos(tractorHeading)
        let rightZ = -sin(tractorHeading)

        let axleX = antennaX + longOffset * forwardX + latOffset * rightX
        let axleZ = antennaZ + longOffset * forwardZ + latOffset * rightZ

        return (axleX, axleZ)
    }

    // MARK: - Step 2: Rear Axle to Hitch

    private func calculateHitchFromRearAxle(
        rearAxle: (x: Double, z: Double),
        tractorHeading: Double
    ) -> (x: Double, z: Double) {
        // Hitch is behind rear axle (negative forward direction)
        let hitchOffset = machineProfile.hitchOffset  // positive = behind axle

        let forwardX = sin(tractorHeading)
        let forwardZ = cos(tractorHeading)

        // Hitch is BEHIND axle, so we go in the opposite of forward direction
        let hitchX = rearAxle.x - hitchOffset * forwardX
        let hitchZ = rearAxle.z - hitchOffset * forwardZ

        return (hitchX, hitchZ)
    }

    // MARK: - Step 3: Pivot Angle Estimation

    private func estimatePivotAngle(
        currentHitch: (x: Double, z: Double),
        tractorHeading: Double,
        steerAngle: Double?,
        deltaTime: Double
    ) -> Double {
        // For pivoting implements, the implement trails behind and its angle
        // depends on the turning radius and implement geometry

        // Method 1: If we have steering angle, predict from turning geometry
        if let steer = steerAngle, abs(steer) > 0.01 {
            // r_turn = wheelbase / tan(δ)
            let turningRadius = machineProfile.wheelbase / tan(abs(steer))

            // Pivot angle approximation based on implement geometry
            // Δθ_pivot ≈ atan2(centerOfRotationOffset, turningRadius)
            let cor = implementProfile.centerOfRotationOffset
            var predictedPivot = atan2(cor, turningRadius)

            // Apply sign based on steering direction
            if steer < 0 {
                predictedPivot = -predictedPivot
            }

            // Clamp to physical limits (typically ±30-45°)
            let maxPivot = 45.0 * .pi / 180  // 45 degrees
            predictedPivot = max(-maxPivot, min(maxPivot, predictedPivot))

            // Smooth the pivot angle
            estimatedPivotAngle = estimatedPivotAngle + pivotAngleSmoothing * (predictedPivot - estimatedPivotAngle)
        }

        // Method 2: Estimate from hitch position history
        if let lastHitch = lastHitchPosition {
            let dx = currentHitch.x - lastHitch.x
            let dz = currentHitch.z - lastHitch.z
            let distance = sqrt(dx * dx + dz * dz)

            // Only update if we've moved enough
            if distance > 0.05 {  // 5cm minimum movement
                // Calculate direction of travel at hitch
                let travelHeading = atan2(dx, dz)

                // Pivot angle is difference from tractor heading
                var observedPivot = travelHeading - tractorHeading

                // Normalize to -π to π
                while observedPivot > .pi { observedPivot -= 2 * .pi }
                while observedPivot < -.pi { observedPivot += 2 * .pi }

                // Smooth the observed pivot angle
                estimatedPivotAngle = estimatedPivotAngle + pivotAngleSmoothing * (observedPivot - estimatedPivotAngle)
            }
        }

        return estimatedPivotAngle
    }

    // MARK: - Step 4: Hitch to Work Point

    private func calculateWorkPointFromHitch(
        hitch: (x: Double, z: Double),
        hitchHeading: Double
    ) -> PositionWithHeading {
        // Work point is behind hitch along the implement direction
        let workOffset = implementProfile.workPointOffset

        let forwardX = sin(hitchHeading)
        let forwardZ = cos(hitchHeading)

        // Work point is BEHIND hitch (opposite of forward direction)
        let workX = hitch.x - workOffset * forwardX
        let workZ = hitch.z - workOffset * forwardZ

        return PositionWithHeading(x: workX, z: workZ, heading: hitchHeading)
    }

    // MARK: - Reset

    func reset() {
        lastHitchPosition = nil
        estimatedPivotAngle = 0
    }
}
