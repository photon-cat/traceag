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

// MARK: - AB Line Model

/// Represents an A-B guidance line with start and end points
struct ABLine {
    /// A point (start) in WGS84 coordinates
    var pointA: CLLocationCoordinate2D

    /// B point (end) in WGS84 coordinates - nil if not yet set
    var pointB: CLLocationCoordinate2D?

    /// Computed heading from A to B in radians (0 = North, clockwise positive)
    var heading: Double {
        guard let b = pointB else {
            return manualHeading
        }
        return calculateBearing(from: pointA, to: b)
    }

    /// Manual heading when B point not set (radians)
    var manualHeading: Double = 0

    /// Length of the AB line in meters (nil if B not set = infinite)
    var length: Double? {
        guard let b = pointB else { return nil }
        return distanceBetween(pointA, b)
    }

    /// Whether B point has been set
    var isComplete: Bool {
        pointB != nil
    }

    // MARK: - Initialization

    init(pointA: CLLocationCoordinate2D, heading: Double = 0) {
        self.pointA = pointA
        self.manualHeading = heading
        self.pointB = nil
    }

    init(pointA: CLLocationCoordinate2D, pointB: CLLocationCoordinate2D) {
        self.pointA = pointA
        self.pointB = pointB
        self.manualHeading = calculateBearing(from: pointA, to: pointB)
    }

    // MARK: - Coordinate Math

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x)
        if bearing < 0 {
            bearing += 2 * .pi
        }
        return bearing
    }

    private func distanceBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let sinDLat = sin(dLat / 2)
        let sinDLon = sin(dLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon

        let earthRadius = 6371000.0  // meters
        return 2 * earthRadius * asin(sqrt(h))
    }
}

// MARK: - Straight AB Guidance Engine

/// Guidance engine for straight AB lines with parallel passes
class StraightABGuidance: GuidanceEngine {
    // MARK: - Properties

    var abLine: ABLine
    var lineSpacing: Double
    var linesDirection: LinesDirection

    /// Reference point for local coordinate conversion (usually A point)
    private let origin: CLLocationCoordinate2D

    /// WGS84 converter for local tangent plane coordinates.
    private let converter: WGS84Converter

    // MARK: - Initialization

    init(abLine: ABLine, lineSpacing: Double = 10.0, linesDirection: LinesDirection = .both) {
        self.abLine = abLine
        self.lineSpacing = lineSpacing
        self.linesDirection = linesDirection
        self.origin = abLine.pointA
        self.converter = WGS84Converter(origin: abLine.pointA)
    }

    // MARK: - Coordinate Conversion

    func wgs84ToLocal(_ coord: CLLocationCoordinate2D) -> (x: Double, z: Double) {
        // x = East, z = North (matches SceneKit where +Z is forward/North)
        converter.wgs84ToLocal(coord)
    }

    func localToWGS84(x: Double, z: Double) -> CLLocationCoordinate2D {
        converter.localToWGS84(x: x, z: z)
    }

    // MARK: - GuidanceEngine Protocol

    func calculateGuidance(
        localX: Double,
        localZ: Double,
        vehicleHeading: Double,
        targetLineIndex: Int
    ) -> GuidanceResult {
        let heading = abLine.heading

        // Unit vector along AB line direction
        let alongX = sin(heading)
        let alongZ = cos(heading)

        // Unit vector perpendicular to AB line (90° clockwise = right side)
        let perpX = cos(heading)
        let perpZ = -sin(heading)

        // Project vehicle position onto AB line coordinate system
        // alongTrack = distance along AB line from A point
        // crossTrack = perpendicular distance (positive = right of line)
        let alongTrack = localX * alongX + localZ * alongZ
        let crossTrack = localX * perpX + localZ * perpZ

        // Find which line index we're closest to
        let rawLineIndex = crossTrack / lineSpacing
        let nearestLineIndex = Int(round(rawLineIndex))

        // Cross-track error relative to target line
        let targetLineOffset = Double(targetLineIndex) * lineSpacing
        let crossTrackError = crossTrack - targetLineOffset

        // Calculate steering heading to return to line
        // Simple proportional guidance - steer toward line
        let correctionGain = 0.3
        let correctionAngle = atan2(-crossTrackError * correctionGain, 10.0)
        let steerToHeading = heading + correctionAngle

        // Check if past end point
        var isPastEnd = false
        if let length = abLine.length {
            isPastEnd = alongTrack > length
        }

        return GuidanceResult(
            crossTrackError: crossTrackError,
            nearestLineIndex: nearestLineIndex,
            steerToHeading: steerToHeading,
            alongTrackDistance: alongTrack,
            isPastEndPoint: isPastEnd
        )
    }

    func getVisibleLines(
        centerX: Double,
        centerZ: Double,
        renderDistance: Double,
        activeLineIndex: Int
    ) -> [GuidanceLine] {
        var lines: [GuidanceLine] = []

        let heading = abLine.heading

        // Perpendicular direction for line offsets
        let perpX = cos(heading)
        let perpZ = -sin(heading)

        // Calculate which line indices are visible
        let crossTrack = centerX * perpX + centerZ * perpZ
        let centerLineIndex = Int(round(crossTrack / lineSpacing))
        let linesNeeded = Int(ceil(renderDistance / lineSpacing)) + 2

        // Determine line range based on direction setting
        let minLine: Int
        let maxLine: Int

        switch linesDirection {
        case .left:
            minLine = centerLineIndex - linesNeeded
            maxLine = min(0, centerLineIndex + linesNeeded)
        case .right:
            minLine = max(0, centerLineIndex - linesNeeded)
            maxLine = centerLineIndex + linesNeeded
        case .both:
            minLine = centerLineIndex - linesNeeded
            maxLine = centerLineIndex + linesNeeded
        }

        // Line length for rendering
        let lineHalfLength = renderDistance * 1.5

        for i in minLine...maxLine {
            let lineOffset = Double(i) * lineSpacing

            // Line center point (perpendicular offset from A point)
            let lineCenterX = lineOffset * perpX
            let lineCenterZ = lineOffset * perpZ

            // Check if line is within render distance
            let distToCenter = sqrt(pow(lineCenterX - centerX, 2) + pow(lineCenterZ - centerZ, 2))
            if distToCenter > renderDistance + lineHalfLength {
                continue
            }

            // Line endpoints (extend in both directions along heading)
            let alongX = sin(heading)
            let alongZ = cos(heading)

            let startX = lineCenterX - alongX * lineHalfLength
            let startZ = lineCenterZ - alongZ * lineHalfLength
            let endX = lineCenterX + alongX * lineHalfLength
            let endZ = lineCenterZ + alongZ * lineHalfLength

            lines.append(GuidanceLine(
                index: i,
                startPoint: CGPoint(x: startX, y: startZ),
                endPoint: CGPoint(x: endX, y: endZ),
                heading: heading,
                isActive: i == activeLineIndex
            ))
        }

        return lines
    }
}
