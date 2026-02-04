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

// MARK: - Guidance Result

/// Result of guidance calculation for current position
struct GuidanceResult {
    /// Cross-track error in meters (positive = right, negative = left)
    let crossTrackError: Double

    /// Index of the nearest guidance line
    let nearestLineIndex: Int

    /// Heading to steer toward to return to line (radians)
    let steerToHeading: Double

    /// Distance along the current line from A point (meters)
    let alongTrackDistance: Double

    /// Whether we're past the B point
    let isPastEndPoint: Bool
}

// MARK: - Guidance Line Info

/// Information about a single guidance line for rendering
struct GuidanceLine {
    let index: Int
    let startPoint: CGPoint  // Local coordinates (x, z)
    let endPoint: CGPoint    // Local coordinates (x, z)
    let heading: Double      // Radians
    let isActive: Bool
}

// MARK: - Guidance Engine Protocol

/// Protocol for guidance calculation engines (straight AB, curved, headlands)
protocol GuidanceEngine {
    /// Calculate guidance for current position
    func calculateGuidance(
        localX: Double,
        localZ: Double,
        vehicleHeading: Double,
        targetLineIndex: Int
    ) -> GuidanceResult

    /// Get guidance lines within render distance for visualization
    func getVisibleLines(
        centerX: Double,
        centerZ: Double,
        renderDistance: Double,
        activeLineIndex: Int
    ) -> [GuidanceLine]

    /// Line spacing in meters
    var lineSpacing: Double { get set }

    /// Direction of lines relative to AB line
    var linesDirection: LinesDirection { get set }
}

// MARK: - Lines Direction

enum LinesDirection: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
}
