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

import SwiftUI
import UIKit

// MARK: - Guidance Color Palette

/// SceneKit colors (UIColor) for 3D visualization
enum GuidanceSceneColors {
    /// Dark grid background - #0F141A
    static let gridBackground = UIColor(red: 0.059, green: 0.078, blue: 0.102, alpha: 1.0)

    /// Major grid lines (5m spacing)
    static let gridMajor = UIColor.white.withAlphaComponent(0.3)

    /// Minor grid lines (1m spacing)
    static let gridMinor = UIColor.white.withAlphaComponent(0.1)

    /// Vehicle body - warm orange
    static let vehicle = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)

    /// Rear axle marker - white
    static let rearAxle = UIColor.white

    /// Velocity tail
    static let velocityTail = UIColor.cyan.withAlphaComponent(0.6)

    /// Hitch point marker - bright cyan
    static let hitchMarker = UIColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 1.0)

    /// Hitch marker halo
    static let hitchHalo = UIColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 0.3)

    /// Implement frame
    static let implement = UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)

    /// Implement center of rotation marker
    static let implementCOR = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)

    /// Guidance path - teal
    static let guidanceTeal = UIColor(red: 0.0, green: 0.75, blue: 0.75, alpha: 1.0)

    /// Guidance path - good confidence
    static let pathGood = UIColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)

    /// Guidance path - degraded confidence
    static let pathDegraded = UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1.0)

    /// Guidance path - invalid
    static let pathInvalid = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)

    /// Lookahead point marker
    static let lookahead = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)

    /// Lateral error indicator
    static let lateralError = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)

    /// Coverage fill - muted green
    static let coverageFill = UIColor(red: 0.2, green: 0.65, blue: 0.3, alpha: 0.5)

    /// Coverage overlap stripe
    static let coverageOverlap = UIColor(red: 0.3, green: 0.75, blue: 0.4, alpha: 0.7)

    /// Active guidance line
    static let lineActive = UIColor.yellow

    /// Inactive guidance line
    static let lineInactive = UIColor.cyan.withAlphaComponent(0.6)

    /// Field boundary
    static let boundary = UIColor.red.withAlphaComponent(0.8)

    /// Scale indicator
    static let scaleIndicator = UIColor.white.withAlphaComponent(0.8)
}

/// SwiftUI colors for HUD overlays
enum GuidanceHUDColors {
    /// Guidance teal - primary guidance color
    static let teal = Color(red: 0.0, green: 0.75, blue: 0.75)

    /// Warning amber
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.0)

    /// Error red
    static let red = Color(red: 0.9, green: 0.3, blue: 0.3)

    /// Success green
    static let green = Color(red: 0.2, green: 0.75, blue: 0.4)

    /// Muted coverage green
    static let coverage = Color(red: 0.2, green: 0.65, blue: 0.3)

    /// Simulator badge blue
    static let simulator = Color(red: 0.3, green: 0.5, blue: 0.9)

    /// Returns color based on lateral error magnitude
    static func lateralErrorColor(_ error: Double) -> Color {
        let absError = abs(error)
        if absError < 0.1 {
            return teal
        } else if absError < 0.5 {
            return .primary
        } else if absError < 2.0 {
            return amber
        } else {
            return red
        }
    }

    /// Returns color based on guidance confidence (0-1)
    static func confidenceColor(_ confidence: Double) -> Color {
        if confidence > 0.7 {
            return teal
        } else if confidence > 0.4 {
            return amber
        } else {
            return red
        }
    }
}

// MARK: - Typography

enum GuidanceTypography {
    /// Large readout (lateral error)
    static let largeReadout = Font.system(.title2, design: .monospaced).weight(.semibold)

    /// Medium readout (heading error)
    static let mediumReadout = Font.system(.subheadline, design: .monospaced).weight(.medium)

    /// Small readout (coordinates, stats)
    static let smallReadout = Font.system(.caption, design: .monospaced)

    /// Label text
    static let label = Font.system(.caption2, design: .default).weight(.medium)

    /// Mode indicator
    static let mode = Font.system(.caption, design: .default).weight(.bold)

    /// Button text
    static let button = Font.system(.subheadline, design: .default).weight(.semibold)
}

// MARK: - Layout Constants

enum GuidanceLayout {
    /// Standard corner radius for HUD elements
    static let cornerRadius: CGFloat = 12

    /// Small corner radius
    static let cornerRadiusSmall: CGFloat = 8

    /// Standard padding
    static let padding: CGFloat = 12

    /// Compact padding
    static let paddingCompact: CGFloat = 8

    /// Standard spacing between elements
    static let spacing: CGFloat = 12

    /// Compact spacing
    static let spacingCompact: CGFloat = 8
}

// MARK: - SceneKit Dimensions

enum GuidanceDimensions {
    /// Vehicle body length (tip to rear)
    static let vehicleLength: Float = 4.0

    /// Vehicle body width
    static let vehicleWidth: Float = 3.0

    /// Rear axle marker width
    static let rearAxleWidth: Float = 3.6

    /// Rear axle marker thickness
    static let rearAxleThickness: Float = 0.15

    /// Hitch marker radius
    static let hitchMarkerRadius: Float = 0.3

    /// Hitch halo radius
    static let hitchHaloRadius: Float = 0.5

    /// Implement COR marker radius
    static let corMarkerRadius: Float = 0.2

    /// Path line width
    static let pathWidth: Float = 0.25

    /// Lookahead marker radius
    static let lookaheadRadius: Float = 0.4

    /// Lateral error line width
    static let errorLineWidth: Float = 0.15

    /// Grid major line width
    static let gridMajorWidth: Float = 0.08

    /// Grid minor line width
    static let gridMinorWidth: Float = 0.04

    /// Default grid major spacing (meters)
    static let gridMajorSpacing: Float = 5.0

    /// Default grid minor spacing (meters)
    static let gridMinorSpacing: Float = 1.0

    /// Scale indicator width (meters)
    static let scaleBarWidth: Float = 10.0

    /// Scale indicator height
    static let scaleBarHeight: Float = 0.3
}

// MARK: - LOD Thresholds

enum GuidanceLOD {
    /// Camera height threshold for high detail (show 1m + 5m lines)
    static let highDetailThreshold: Float = 50.0

    /// Camera height threshold for medium detail (show 5m lines only)
    static let mediumDetailThreshold: Float = 150.0

    /// Above this, show 10m lines only
    static let lowDetailSpacing: Float = 10.0
}
