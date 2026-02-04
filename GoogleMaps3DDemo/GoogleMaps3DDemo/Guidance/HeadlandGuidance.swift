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

/// Guidance engine for headland paths based on boundary polygons.
final class HeadlandGuidance: GuidanceEngine {
    var boundary: [CGPoint]
    var lineSpacing: Double
    var linesDirection: LinesDirection

    init(boundary: [CGPoint], lineSpacing: Double = 6.0, linesDirection: LinesDirection = .both) {
        self.boundary = boundary
        self.lineSpacing = lineSpacing
        self.linesDirection = linesDirection
    }

    func calculateGuidance(
        localX: Double,
        localZ: Double,
        vehicleHeading: Double,
        targetLineIndex: Int
    ) -> GuidanceResult {
        guard boundary.count >= 3 else {
            return GuidanceResult(
                crossTrackError: 0,
                nearestLineIndex: 0,
                steerToHeading: vehicleHeading,
                alongTrackDistance: 0,
                isPastEndPoint: false
            )
        }

        let point = CGPoint(x: localX, y: localZ)
        var bestProjection: GuidanceGeometry.SegmentProjection?
        var alongDistance = 0.0
        var bestAlongDistance = 0.0

        var loopPoints = boundary
        loopPoints.append(boundary[0])

        for (a, b) in GuidanceGeometry.polylineSegments(points: loopPoints) {
            let projection = GuidanceGeometry.segmentProjection(point: point, a: a, b: b)
            let segLen = hypot(Double(b.x - a.x), Double(b.y - a.y))
            if let currentBest = bestProjection {
                if projection.distance < currentBest.distance {
                    bestProjection = projection
                    bestAlongDistance = alongDistance + projection.t * segLen
                }
            } else {
                bestProjection = projection
                bestAlongDistance = alongDistance + projection.t * segLen
            }
            alongDistance += segLen
        }

        guard let projection = bestProjection else {
            return GuidanceResult(
                crossTrackError: 0,
                nearestLineIndex: 0,
                steerToHeading: vehicleHeading,
                alongTrackDistance: 0,
                isPastEndPoint: false
            )
        }

        let inside = GuidanceGeometry.pointInsidePolygon(point: point, polygon: boundary)
        let signedDistance = inside ? -projection.distance : projection.distance
        let nearestLineIndex = Int(round(signedDistance / lineSpacing))
        let targetOffset = Double(targetLineIndex) * lineSpacing
        let crossTrackError = signedDistance - targetOffset

        let correctionGain = 0.3
        let correctionAngle = atan2(-crossTrackError * correctionGain, 10.0)
        let steerToHeading = projection.heading + correctionAngle

        return GuidanceResult(
            crossTrackError: crossTrackError,
            nearestLineIndex: nearestLineIndex,
            steerToHeading: steerToHeading,
            alongTrackDistance: bestAlongDistance,
            isPastEndPoint: false
        )
    }

    func getVisibleLines(
        centerX: Double,
        centerZ: Double,
        renderDistance: Double,
        activeLineIndex: Int
    ) -> [GuidanceLine] {
        guard boundary.count >= 3 else { return [] }
        var lines: [GuidanceLine] = []
        let maxRings = Int(renderDistance / lineSpacing) + 1

        for ring in -maxRings...maxRings {
            let offset = Double(ring) * lineSpacing
            let ringPoints = GuidanceGeometry.offsetPolygon(points: boundary, offset: offset)
            guard ringPoints.count >= 3 else { continue }

            var loopPoints = ringPoints
            loopPoints.append(ringPoints[0])

            for (a, b) in GuidanceGeometry.polylineSegments(points: loopPoints) {
                let midX = (a.x + b.x) / 2
                let midZ = (a.y + b.y) / 2
                if hypot(Double(midX - centerX), Double(midZ - centerZ)) > renderDistance * 1.5 {
                    continue
                }

                let heading = atan2(Double(b.x - a.x), Double(b.y - a.y))
                lines.append(GuidanceLine(
                    index: ring,
                    startPoint: a,
                    endPoint: b,
                    heading: heading,
                    isActive: ring == activeLineIndex
                ))
            }
        }

        return lines
    }
}
