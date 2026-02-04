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

struct GuidanceGeometry {
    struct SegmentProjection {
        let t: Double
        let projection: CGPoint
        let distance: Double
        let crossTrack: Double
        let heading: Double
    }

    static func polylineSegments(points: [CGPoint]) -> [(CGPoint, CGPoint)] {
        guard points.count >= 2 else { return [] }
        return zip(points.dropLast(), points.dropFirst()).map { ($0, $1) }
    }

    static func polylineLength(points: [CGPoint]) -> Double {
        polylineSegments(points: points).reduce(0.0) { length, segment in
            let dx = segment.1.x - segment.0.x
            let dz = segment.1.y - segment.0.y
            return length + hypot(Double(dx), Double(dz))
        }
    }

    static func segmentProjection(point: CGPoint, a: CGPoint, b: CGPoint) -> SegmentProjection {
        let dx = Double(b.x - a.x)
        let dz = Double(b.y - a.y)
        let segLenSq = dx * dx + dz * dz
        if segLenSq <= 1e-9 {
            return SegmentProjection(
                t: 0.0,
                projection: a,
                distance: hypot(Double(point.x - a.x), Double(point.y - a.y)),
                crossTrack: 0.0,
                heading: 0.0
            )
        }

        let px = Double(point.x - a.x)
        let pz = Double(point.y - a.y)
        var t = (px * dx + pz * dz) / segLenSq
        t = max(0.0, min(1.0, t))
        let proj = CGPoint(x: a.x + CGFloat(t) * (b.x - a.x), y: a.y + CGFloat(t) * (b.y - a.y))
        let dist = hypot(Double(point.x - proj.x), Double(point.y - proj.y))
        let segLen = sqrt(segLenSq)
        let cross = segLen > 1e-9 ? (px * dz - pz * dx) / segLen : 0.0
        let heading = atan2(dx, dz)

        return SegmentProjection(t: t, projection: proj, distance: dist, crossTrack: cross, heading: heading)
    }

    static func polygonArea(points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0.0 }
        var area = 0.0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += Double(points[i].x * points[j].y - points[j].x * points[i].y)
        }
        return 0.5 * area
    }

    static func offsetPolygon(points: [CGPoint], offset: Double) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        let area = polygonArea(points: points)
        let outward = area > 0 ? -1.0 : 1.0
        var result: [CGPoint] = []

        for i in 0..<points.count {
            let prev = points[(i - 1 + points.count) % points.count]
            let curr = points[i]
            let next = points[(i + 1) % points.count]

            let dx1 = Double(curr.x - prev.x)
            let dz1 = Double(curr.y - prev.y)
            let dx2 = Double(next.x - curr.x)
            let dz2 = Double(next.y - curr.y)

            let len1 = hypot(dx1, dz1)
            let len2 = hypot(dx2, dz2)
            if len1 <= 1e-6 || len2 <= 1e-6 {
                result.append(curr)
                continue
            }

            let n1x = outward * dz1 / len1
            let n1z = outward * -dx1 / len1
            let n2x = outward * dz2 / len2
            let n2z = outward * -dx2 / len2

            var nx = n1x + n2x
            var nz = n1z + n2z
            let norm = hypot(nx, nz)
            if norm <= 1e-6 {
                nx = n1x
                nz = n1z
            } else {
                nx /= norm
                nz /= norm
            }

            let offsetPoint = CGPoint(
                x: curr.x + CGFloat(nx * offset),
                y: curr.y + CGFloat(nz * offset)
            )
            result.append(offsetPoint)
        }

        return result
    }

    static func pointInsidePolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].x
            let zi = polygon[i].y
            let xj = polygon[j].x
            let zj = polygon[j].y
            let intersect = ((zi > point.y) != (zj > point.y)) &&
                (point.x < (xj - xi) * (point.y - zi) / (zj - zi + 1e-9) + xi)
            if intersect {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
