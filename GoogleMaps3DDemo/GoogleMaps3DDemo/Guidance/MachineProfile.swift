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

// MARK: - Machine Profile

/// Configuration for the tractor/vehicle geometry
struct MachineProfile: Codable, Equatable {
    /// Name of this profile
    var name: String = "Default Machine"

    // MARK: - Vehicle Geometry

    /// Distance between front and rear axles (meters)
    var wheelbase: Double = 2.5

    /// Maximum steering angle the machine can achieve (degrees)
    var maxSteerAngle: Double = 35.0

    /// Distance from rear axle to hitch/3-point (meters, positive = behind axle)
    var hitchOffset: Double = 0.5

    // MARK: - Antenna Offsets (relative to rear axle center)

    /// Antenna height above ground (meters)
    var antennaHeight: Double = 2.5

    /// Antenna lateral offset from centerline (meters, positive = right)
    var antennaLateralOffset: Double = 0.0

    /// Antenna longitudinal offset from rear axle (meters, positive = forward)
    var antennaLongOffset: Double = 0.0

    // MARK: - Computed Properties

    /// Maximum steering angle in radians
    var maxSteerAngleRadians: Double {
        maxSteerAngle * .pi / 180
    }

    /// Minimum turning radius based on wheelbase and max steer angle (meters)
    var minTurningRadius: Double {
        guard maxSteerAngle > 0 else { return .infinity }
        return wheelbase / tan(maxSteerAngleRadians)
    }
}

// MARK: - Implement Profile

/// Configuration for the implement attached to the machine
struct ImplementProfile: Codable, Equatable {
    /// Name of this profile
    var name: String = "Default Implement"

    // MARK: - Implement Type

    /// Whether the implement pivots behind the hitch
    var isPivoting: Bool = false

    // MARK: - Geometry

    /// Distance from hitch to center of rotation (meters)
    /// For pivoting implements, this is where the implement pivots
    /// For non-pivoting, this is typically 0
    var centerOfRotationOffset: Double = 0.0

    /// Distance from hitch to work point (meters)
    /// The work point is where coverage is painted and guidance targets
    var workPointOffset: Double = 3.0

    /// Width of the working area (meters) - swath width
    var workAreaWidth: Double = 6.0

    // MARK: - Computed Properties

    /// Half width for coverage calculations
    var halfWidth: Double {
        workAreaWidth / 2
    }
}

// MARK: - Combined Vehicle Configuration

/// Complete vehicle configuration combining machine and implement
struct VehicleConfiguration: Codable, Equatable {
    var machine: MachineProfile = MachineProfile()
    var implement: ImplementProfile = ImplementProfile()

    /// Calculate the work point position relative to the antenna position
    /// Returns (longitudinal offset, lateral offset) in meters
    /// Longitudinal: positive = behind antenna
    /// Lateral: positive = right of antenna
    func workPointOffsetFromAntenna() -> (longitudinal: Double, lateral: Double) {
        // Antenna to rear axle
        let antennaToRearAxle = -machine.antennaLongOffset

        // Rear axle to hitch
        let rearAxleToHitch = machine.hitchOffset

        // Hitch to work point
        let hitchToWorkPoint = implement.workPointOffset

        // Total longitudinal offset (all behind = positive)
        let longitudinal = antennaToRearAxle + rearAxleToHitch + hitchToWorkPoint

        // Lateral is just the antenna offset (inverted since we want offset FROM antenna)
        let lateral = -machine.antennaLateralOffset

        return (longitudinal, lateral)
    }
}
