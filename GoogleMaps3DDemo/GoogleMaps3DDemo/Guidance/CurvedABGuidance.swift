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

/// Guidance engine for curved AB lines represented as a polyline.
final class CurvedABGuidance: GuidanceEngine {
    var centerline: [CGPoint]
    var lineSpacing: Double
    var linesDirection: LinesDirection

    private let totalLength: Double

    init(centerline: [CGPoint], lineSpacing: Double = 10.0, linesDirection: LinesDirection = .both) {
        self.centerline = centerline
        self.lineSpacing = lineSpacing
        self.linesDirection = linesDirection
        self.totalLength = GuidanceGeometry.polylineLength(points: centerline)
    }

    func calculateGuidance(
        localX: Double,
        localZ: Double,
        vehicleHeading: Double,
        targetLineIndex: Int
    ) -> GuidanceResult {
        guard centerline.count >= 2 else {
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

        for (a, b) in GuidanceGeometry.polylineSegments(points: centerline) {
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

        let nearestLineIndex = Int(round(projection.crossTrack / lineSpacing))
        let targetOffset = Double(targetLineIndex) * lineSpacing
        let crossTrackError = projection.crossTrack - targetOffset

        let correctionGain = 0.3
        let correctionAngle = atan2(-crossTrackError * correctionGain, 10.0)
        let steerToHeading = projection.heading + correctionAngle

        let isPastEnd = bestAlongDistance > totalLength

        return GuidanceResult(
            crossTrackError: crossTrackError,
            nearestLineIndex: nearestLineIndex,
            steerToHeading: steerToHeading,
            alongTrackDistance: bestAlongDistance,
            isPastEndPoint: isPastEnd
        )
    }

    func getVisibleLines(
        centerX: Double,
        centerZ: Double,
        renderDistance: Double,
        activeLineIndex: Int
    ) -> [GuidanceLine] {
        guard centerline.count >= 2 else { return [] }
        var lines: [GuidanceLine] = []

        let centerPoint = CGPoint(x: centerX, y: centerZ)
        var nearestCross: Double?
        for (a, b) in GuidanceGeometry.polylineSegments(points: centerline) {
            let projection = GuidanceGeometry.segmentProjection(point: centerPoint, a: a, b: b)
            if nearestCross == nil || projection.distance < abs(nearestCross ?? 0) {
                nearestCross = projection.crossTrack
            }
        }
        let centerLineIndex = Int(round((nearestCross ?? 0) / lineSpacing))
        let linesNeeded = Int(ceil(renderDistance / lineSpacing)) + 2

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

        let segments = GuidanceGeometry.polylineSegments(points: centerline)
        for index in minLine...maxLine {
            let offset = Double(index) * lineSpacing
            for (a, b) in segments {
                let dx = Double(b.x - a.x)
                let dz = Double(b.y - a.y)
                let segLen = hypot(dx, dz)
                if segLen <= 1e-6 {
                    continue
                }
                let perpX = dz / segLen
                let perpZ = -dx / segLen

                let start = CGPoint(x: a.x + CGFloat(perpX * offset), y: a.y + CGFloat(perpZ * offset))
                let end = CGPoint(x: b.x + CGFloat(perpX * offset), y: b.y + CGFloat(perpZ * offset))
                let midX = (start.x + end.x) / 2
                let midZ = (start.y + end.y) / 2

                if hypot(Double(midX - centerX), Double(midZ - centerZ)) > renderDistance * 1.5 {
                    continue
                }

                let heading = atan2(dx, dz)
                lines.append(GuidanceLine(
                    index: index,
                    startPoint: start,
                    endPoint: end,
                    heading: heading,
                    isActive: index == activeLineIndex
                ))
            }
        }

        return lines
    }
}
