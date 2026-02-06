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
import CoreGraphics

/// Result of track vector calculation
struct TrackVectorResult {
    /// Points along the desired path (local coordinates)
    let desiredPath: [CGPoint]

    /// Lookahead point on the desired path
    let lookaheadPoint: CGPoint

    /// Vehicle reference point projected onto path
    let projectedPoint: CGPoint

    /// Lateral (cross-track) error in meters (positive = right of path)
    let lateralError: Double

    /// Heading error in radians (positive = clockwise from path tangent)
    let headingError: Double

    /// Guidance confidence (0-1)
    let confidence: Double

    /// Along-track distance from path start
    let alongTrackDistance: Double
}

/// Calculates track vector, lookahead points, and guidance errors
struct TrackVectorCalculator {

    // MARK: - Configuration

    /// Default lookahead distance in meters
    static let defaultLookaheadDistance: Double = 10.0

    /// Default path length to generate in meters
    static let defaultPathLength: Double = 50.0

    /// Number of points to generate along path
    static let pathPointCount: Int = 25

    // MARK: - Straight Line Guidance

    /// Calculate track vector for straight AB line guidance
    /// - Parameters:
    ///   - vehicleX: Vehicle X position (local coords, meters)
    ///   - vehicleZ: Vehicle Z position (local coords, meters)
    ///   - vehicleHeading: Vehicle heading in radians (0 = north, CW positive)
    ///   - targetLineIndex: Current target guidance line index
    ///   - lineSpacing: Spacing between guidance lines in meters
    ///   - abHeading: AB line heading in radians
    ///   - lookaheadDistance: Distance ahead for lookahead point
    ///   - pathLength: Length of path to generate
    ///   - gnssAccuracy: GNSS horizontal accuracy (for confidence calculation)
    /// - Returns: TrackVectorResult with all guidance data
    static func calculateStraightLine(
        vehicleX: Double,
        vehicleZ: Double,
        vehicleHeading: Double,
        targetLineIndex: Int,
        lineSpacing: Double,
        abHeading: Double,
        lookaheadDistance: Double = defaultLookaheadDistance,
        pathLength: Double = defaultPathLength,
        gnssAccuracy: Double = 0
    ) -> TrackVectorResult {
        // Unit vectors for AB line coordinate system
        // Along direction (direction of travel on line)
        let alongX = sin(abHeading)
        let alongZ = cos(abHeading)

        // Perpendicular direction (positive = right of line)
        let perpX = cos(abHeading)
        let perpZ = -sin(abHeading)

        // Target line offset from origin
        let targetOffset = Double(targetLineIndex) * lineSpacing

        // Vehicle position in line coordinate system
        let vehicleAlong = vehicleX * alongX + vehicleZ * alongZ
        let vehicleCross = vehicleX * perpX + vehicleZ * perpZ

        // Lateral error (positive = vehicle is right of line)
        let lateralError = vehicleCross - targetOffset

        // Heading error (positive = vehicle heading clockwise from line heading)
        var headingError = vehicleHeading - abHeading
        // Normalize to -π to π
        while headingError > .pi { headingError -= 2 * .pi }
        while headingError < -.pi { headingError += 2 * .pi }

        // Generate path points along target line
        // Start slightly behind vehicle, extend forward
        let startAlong = vehicleAlong - 5.0
        var pathPoints: [CGPoint] = []

        for i in 0..<pathPointCount {
            let t = Double(i) / Double(pathPointCount - 1)
            let alongDist = startAlong + t * (pathLength + 5.0)

            // Convert back to world coordinates
            let pointX = targetOffset * perpX + alongDist * alongX
            let pointZ = targetOffset * perpZ + alongDist * alongZ

            pathPoints.append(CGPoint(x: pointX, y: pointZ))
        }

        // Lookahead point
        let lookaheadAlong = vehicleAlong + lookaheadDistance
        let lookaheadX = targetOffset * perpX + lookaheadAlong * alongX
        let lookaheadZ = targetOffset * perpZ + lookaheadAlong * alongZ
        let lookaheadPoint = CGPoint(x: lookaheadX, y: lookaheadZ)

        // Projected point (vehicle position projected onto target line)
        let projectedX = targetOffset * perpX + vehicleAlong * alongX
        let projectedZ = targetOffset * perpZ + vehicleAlong * alongZ
        let projectedPoint = CGPoint(x: projectedX, y: projectedZ)

        // Calculate confidence
        let confidence = calculateConfidence(
            lateralError: lateralError,
            headingError: headingError,
            gnssAccuracy: gnssAccuracy
        )

        return TrackVectorResult(
            desiredPath: pathPoints,
            lookaheadPoint: lookaheadPoint,
            projectedPoint: projectedPoint,
            lateralError: lateralError,
            headingError: headingError,
            confidence: confidence,
            alongTrackDistance: vehicleAlong
        )
    }

    // MARK: - Curved Line Guidance

    /// Calculate track vector for curved path guidance
    /// - Parameters:
    ///   - vehicleX: Vehicle X position
    ///   - vehicleZ: Vehicle Z position
    ///   - vehicleHeading: Vehicle heading in radians
    ///   - pathPoints: Reference path points (centerline)
    ///   - offset: Lateral offset from centerline (positive = right)
    ///   - lookaheadDistance: Distance ahead for lookahead point
    ///   - gnssAccuracy: GNSS accuracy for confidence
    /// - Returns: TrackVectorResult
    static func calculateCurved(
        vehicleX: Double,
        vehicleZ: Double,
        vehicleHeading: Double,
        pathPoints: [CGPoint],
        offset: Double,
        lookaheadDistance: Double = defaultLookaheadDistance,
        gnssAccuracy: Double = 0
    ) -> TrackVectorResult? {
        guard pathPoints.count >= 2 else { return nil }

        // Find closest segment on path
        var minDist = Double.infinity
        var closestSegmentIndex = 0
        var closestT: Double = 0
        var closestProjection = CGPoint.zero

        for i in 0..<pathPoints.count - 1 {
            let p1 = pathPoints[i]
            let p2 = pathPoints[i + 1]

            let result = projectPointOntoSegment(
                point: CGPoint(x: vehicleX, y: vehicleZ),
                segmentStart: p1,
                segmentEnd: p2
            )

            if result.distance < minDist {
                minDist = result.distance
                closestSegmentIndex = i
                closestT = result.t
                closestProjection = result.projection
            }
        }

        // Calculate segment heading at closest point
        let p1 = pathPoints[closestSegmentIndex]
        let p2 = pathPoints[min(closestSegmentIndex + 1, pathPoints.count - 1)]
        let segmentHeading = atan2(p2.x - p1.x, p2.y - p1.y)

        // Lateral error (signed distance from path)
        let perpX = cos(segmentHeading)
        let perpZ = -sin(segmentHeading)
        let toVehicleX = vehicleX - Double(closestProjection.x)
        let toVehicleZ = vehicleZ - Double(closestProjection.y)
        let lateralError = toVehicleX * perpX + toVehicleZ * perpZ - offset

        // Heading error
        var headingError = vehicleHeading - segmentHeading
        while headingError > .pi { headingError -= 2 * .pi }
        while headingError < -.pi { headingError += 2 * .pi }

        // Generate offset path
        var offsetPath: [CGPoint] = []
        for i in 0..<pathPoints.count - 1 {
            let p1 = pathPoints[i]
            let p2 = pathPoints[i + 1]
            let heading = atan2(Double(p2.x - p1.x), Double(p2.y - p1.y))
            let offsetX = cos(heading) * offset
            let offsetZ = -sin(heading) * offset
            offsetPath.append(CGPoint(x: Double(p1.x) + offsetX, y: Double(p1.y) + offsetZ))
        }
        if let last = pathPoints.last, pathPoints.count >= 2 {
            let prev = pathPoints[pathPoints.count - 2]
            let heading = atan2(Double(last.x - prev.x), Double(last.y - prev.y))
            let offsetX = cos(heading) * offset
            let offsetZ = -sin(heading) * offset
            offsetPath.append(CGPoint(x: Double(last.x) + offsetX, y: Double(last.y) + offsetZ))
        }

        // Lookahead point (travel along path from current position)
        let lookaheadPoint = findPointAtDistance(
            from: closestProjection,
            alongPath: offsetPath,
            startIndex: closestSegmentIndex,
            distance: lookaheadDistance
        )

        // Along-track distance (approximate)
        var alongTrack: Double = 0
        for i in 0..<closestSegmentIndex {
            let dx = pathPoints[i + 1].x - pathPoints[i].x
            let dz = pathPoints[i + 1].y - pathPoints[i].y
            alongTrack += sqrt(dx * dx + dz * dz)
        }
        let segDx = p2.x - p1.x
        let segDz = p2.y - p1.y
        alongTrack += sqrt(segDx * segDx + segDz * segDz) * closestT

        let confidence = calculateConfidence(
            lateralError: lateralError,
            headingError: headingError,
            gnssAccuracy: gnssAccuracy
        )

        return TrackVectorResult(
            desiredPath: offsetPath,
            lookaheadPoint: lookaheadPoint,
            projectedPoint: closestProjection,
            lateralError: lateralError,
            headingError: headingError,
            confidence: confidence,
            alongTrackDistance: alongTrack
        )
    }

    // MARK: - Helpers

    /// Calculate guidance confidence based on errors and GNSS quality
    private static func calculateConfidence(
        lateralError: Double,
        headingError: Double,
        gnssAccuracy: Double
    ) -> Double {
        // Error penalty (0-0.5 based on lateral error)
        let errorPenalty = min(abs(lateralError) / 5.0, 0.5)

        // Heading penalty (0-0.2 based on heading error)
        let headingPenalty = min(abs(headingError) / .pi * 0.4, 0.2)

        // GNSS accuracy penalty (0-0.3)
        let gnssPenalty = gnssAccuracy > 0 ? min(gnssAccuracy / 10.0, 0.3) : 0

        return max(0, min(1, 1.0 - errorPenalty - headingPenalty - gnssPenalty))
    }

    /// Project a point onto a line segment
    private static func projectPointOntoSegment(
        point: CGPoint,
        segmentStart: CGPoint,
        segmentEnd: CGPoint
    ) -> (projection: CGPoint, distance: Double, t: Double) {
        let dx = segmentEnd.x - segmentStart.x
        let dz = segmentEnd.y - segmentStart.y
        let lengthSq = dx * dx + dz * dz

        guard lengthSq > 0.0001 else {
            let dist = hypot(point.x - segmentStart.x, point.y - segmentStart.y)
            return (segmentStart, dist, 0)
        }

        // Parameter t along segment (0 = start, 1 = end)
        var t = ((point.x - segmentStart.x) * dx + (point.y - segmentStart.y) * dz) / lengthSq
        t = max(0, min(1, t))

        let projX = segmentStart.x + t * dx
        let projZ = segmentStart.y + t * dz
        let projection = CGPoint(x: projX, y: projZ)

        let distance = hypot(point.x - projX, point.y - projZ)

        return (projection, distance, t)
    }

    /// Find a point at a given distance along a path
    private static func findPointAtDistance(
        from startPoint: CGPoint,
        alongPath path: [CGPoint],
        startIndex: Int,
        distance: Double
    ) -> CGPoint {
        guard !path.isEmpty else { return startPoint }

        var remaining = distance
        var currentPoint = startPoint

        for i in startIndex..<path.count - 1 {
            let nextPoint = path[i + 1]
            let segmentLength = hypot(nextPoint.x - currentPoint.x, nextPoint.y - currentPoint.y)

            if segmentLength >= remaining {
                // Interpolate along this segment
                let t = remaining / segmentLength
                return CGPoint(
                    x: currentPoint.x + t * (nextPoint.x - currentPoint.x),
                    y: currentPoint.y + t * (nextPoint.y - currentPoint.y)
                )
            }

            remaining -= segmentLength
            currentPoint = nextPoint
        }

        // Reached end of path, extrapolate from last segment
        if path.count >= 2 {
            let last = path[path.count - 1]
            let prev = path[path.count - 2]
            let dx = last.x - prev.x
            let dz = last.y - prev.y
            let length = hypot(dx, dz)
            if length > 0.001 {
                let scale = remaining / length
                return CGPoint(x: last.x + dx * scale, y: last.y + dz * scale)
            }
        }

        return path.last ?? startPoint
    }
}
