"""
AB Line Guidance System

Provides cross-track error and heading error for AB line guidance.
"""

import math
from dataclasses import dataclass
from typing import Iterable, List, Optional, Tuple

from .localizer import Pose


Point2D = Tuple[float, float]


def _segment_projection(px: float, py: float, ax: float, ay: float,
                        bx: float, by: float) -> Tuple[float, float, float]:
    """Project point onto segment, returning (t, proj_x, proj_y)."""
    dx = bx - ax
    dy = by - ay
    seg_len_sq = dx * dx + dy * dy
    if seg_len_sq <= 1e-9:
        return 0.0, ax, ay
    t = ((px - ax) * dx + (py - ay) * dy) / seg_len_sq
    t = max(0.0, min(1.0, t))
    return t, ax + t * dx, ay + t * dy


def _segment_cross(px: float, py: float, ax: float, ay: float,
                   bx: float, by: float) -> float:
    """Signed cross product for point relative to segment direction."""
    dx = bx - ax
    dy = by - ay
    seg_len = math.hypot(dx, dy)
    if seg_len <= 1e-9:
        return 0.0
    return ((px - ax) * dy - (py - ay) * dx) / seg_len


def _polyline_segments(points: Iterable[Point2D]) -> List[Tuple[Point2D, Point2D]]:
    pts = list(points)
    return list(zip(pts[:-1], pts[1:]))


def _polyline_length(points: Iterable[Point2D]) -> float:
    length = 0.0
    for (ax, ay), (bx, by) in _polyline_segments(points):
        length += math.hypot(bx - ax, by - ay)
    return length


def _polygon_area(points: Iterable[Point2D]) -> float:
    pts = list(points)
    if len(pts) < 3:
        return 0.0
    area = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        area += (x1 * y2 - x2 * y1)
    return 0.5 * area


def _offset_polygon(points: Iterable[Point2D], offset: float) -> List[Point2D]:
    pts = list(points)
    if len(pts) < 3:
        return pts

    area = _polygon_area(pts)
    outward = -1.0 if area > 0 else 1.0

    offsets: List[Point2D] = []
    for i in range(len(pts)):
        prev_x, prev_y = pts[i - 1]
        curr_x, curr_y = pts[i]
        next_x, next_y = pts[(i + 1) % len(pts)]

        dx1 = curr_x - prev_x
        dy1 = curr_y - prev_y
        dx2 = next_x - curr_x
        dy2 = next_y - curr_y

        len1 = math.hypot(dx1, dy1)
        len2 = math.hypot(dx2, dy2)
        if len1 <= 1e-6 or len2 <= 1e-6:
            offsets.append((curr_x, curr_y))
            continue

        n1x = outward * dy1 / len1
        n1y = outward * -dx1 / len1
        n2x = outward * dy2 / len2
        n2y = outward * -dx2 / len2

        nx = n1x + n2x
        ny = n1y + n2y
        norm = math.hypot(nx, ny)
        if norm <= 1e-6:
            nx, ny = n1x, n1y
            norm = 1.0
        nx /= norm
        ny /= norm

        offsets.append((curr_x + nx * offset, curr_y + ny * offset))
    return offsets

@dataclass
class ABLine:
    """AB guidance line."""
    a_x: float = 0.0
    a_y: float = 0.0
    b_x: float = 0.0
    b_y: float = 0.0

    @property
    def heading(self) -> float:
        """Line heading from A to B."""
        return math.atan2(self.b_x - self.a_x, self.b_y - self.a_y)

    @property
    def length(self) -> float:
        """Line length."""
        dx = self.b_x - self.a_x
        dy = self.b_y - self.a_y
        return math.sqrt(dx*dx + dy*dy)

    @property
    def is_valid(self) -> bool:
        """Check if line is valid (has length)."""
        return self.length > 0.1


class ABGuidance:
    """
    AB line guidance calculator.

    Calculates cross-track error and heading error relative to parallel AB lines.
    """

    def __init__(self, swath_width: float = 6.0):
        self.swath_width = swath_width
        self.ab_line: Optional[ABLine] = None

        # Current guidance state
        self.cross_track_error = 0.0  # positive = right of line
        self.heading_error = 0.0      # positive = heading right of line
        self.active_line_index = 0    # which parallel line we're on

    def set_a_point(self, x: float, y: float) -> None:
        """Set A point of AB line."""
        self.ab_line = ABLine(a_x=x, a_y=y, b_x=x, b_y=y)

    def set_b_point(self, x: float, y: float) -> None:
        """Set B point of AB line."""
        if self.ab_line:
            self.ab_line.b_x = x
            self.ab_line.b_y = y

    def clear(self) -> None:
        """Clear AB line."""
        self.ab_line = None
        self.cross_track_error = 0.0
        self.heading_error = 0.0
        self.active_line_index = 0

    def update(self, pose: Pose) -> None:
        """Update guidance calculations for current pose."""
        if not self.ab_line or not self.ab_line.is_valid:
            self.cross_track_error = 0.0
            self.heading_error = 0.0
            return

        # Line direction vector (normalized)
        line_dx = self.ab_line.b_x - self.ab_line.a_x
        line_dy = self.ab_line.b_y - self.ab_line.a_y
        line_len = math.sqrt(line_dx*line_dx + line_dy*line_dy)
        line_dx /= line_len
        line_dy /= line_len

        # Vector from A to pose
        px = pose.x - self.ab_line.a_x
        py = pose.y - self.ab_line.a_y

        # Cross-track distance (perpendicular distance to line)
        # Positive = right of line when facing from A to B
        cross = px * line_dy - py * line_dx

        # Find which parallel line we're closest to
        self.active_line_index = round(cross / self.swath_width)

        # Cross-track error relative to nearest parallel line
        self.cross_track_error = cross - self.active_line_index * self.swath_width

        # Heading error
        line_heading = self.ab_line.heading
        self.heading_error = pose.heading - line_heading

        # Normalize to [-pi, pi]
        while self.heading_error > math.pi:
            self.heading_error -= 2 * math.pi
        while self.heading_error < -math.pi:
            self.heading_error += 2 * math.pi

    def get_visible_lines(self, center_x: float, center_y: float,
                          render_distance: float) -> List[Tuple[float, float, float, float, bool]]:
        """
        Get AB lines visible within render distance.

        Returns list of (x1, y1, x2, y2, is_active) tuples.
        """
        if not self.ab_line or not self.ab_line.is_valid:
            return []

        lines = []

        # Line direction
        heading = self.ab_line.heading
        sin_h = math.sin(heading)
        cos_h = math.cos(heading)

        # Perpendicular direction (for offsets)
        perp_x = cos_h
        perp_y = -sin_h

        # Calculate how many lines to render
        num_lines = int(render_distance / self.swath_width) + 2

        for i in range(-num_lines, num_lines + 1):
            # Offset from AB line
            offset = i * self.swath_width

            # Point on this parallel line (offset from A point)
            line_x = self.ab_line.a_x + perp_x * offset
            line_y = self.ab_line.a_y + perp_y * offset

            # Extend line in both directions
            x1 = line_x - sin_h * render_distance
            y1 = line_y - cos_h * render_distance
            x2 = line_x + sin_h * render_distance
            y2 = line_y + cos_h * render_distance

            is_active = (i == self.active_line_index)
            lines.append((x1, y1, x2, y2, is_active))

        return lines

    def get_guidance_bar_position(self, bar_width: float = 10.0) -> float:
        """
        Get position for guidance bar indicator.

        Returns value from -1 to 1, where 0 is centered.
        """
        if abs(self.cross_track_error) > bar_width / 2:
            return 1.0 if self.cross_track_error > 0 else -1.0
        return self.cross_track_error / (bar_width / 2)


class CurvedABGuidance:
    """
    Curved AB guidance using a polyline center path.

    Calculates cross-track error and heading error relative to the nearest
    segment on the curve and parallel offset passes.
    """

    def __init__(self, centerline: List[Point2D], swath_width: float = 6.0):
        self.centerline = centerline
        self.swath_width = swath_width

        self.cross_track_error = 0.0
        self.heading_error = 0.0
        self.active_line_index = 0
        self.along_track_distance = 0.0

    def update(self, pose: Pose) -> None:
        if len(self.centerline) < 2:
            self.cross_track_error = 0.0
            self.heading_error = 0.0
            self.active_line_index = 0
            self.along_track_distance = 0.0
            return

        best_distance = float("inf")
        best_segment = None
        along_distance = 0.0
        distance_to_best = 0.0

        segments = _polyline_segments(self.centerline)
        total_distance = 0.0
        for (ax, ay), (bx, by) in segments:
            seg_len = math.hypot(bx - ax, by - ay)
            t, proj_x, proj_y = _segment_projection(pose.x, pose.y, ax, ay, bx, by)
            dist = math.hypot(pose.x - proj_x, pose.y - proj_y)
            if dist < best_distance:
                best_distance = dist
                best_segment = (ax, ay, bx, by)
                distance_to_best = total_distance + t * seg_len
            total_distance += seg_len

        if best_segment is None:
            return

        ax, ay, bx, by = best_segment
        cross = _segment_cross(pose.x, pose.y, ax, ay, bx, by)
        seg_heading = math.atan2(bx - ax, by - ay)

        self.active_line_index = round(cross / self.swath_width)
        self.cross_track_error = cross - self.active_line_index * self.swath_width
        self.heading_error = pose.heading - seg_heading
        self.along_track_distance = distance_to_best

        while self.heading_error > math.pi:
            self.heading_error -= 2 * math.pi
        while self.heading_error < -math.pi:
            self.heading_error += 2 * math.pi

    def get_visible_lines(self, center_x: float, center_y: float,
                          render_distance: float) -> List[Tuple[float, float, float, float, bool]]:
        if len(self.centerline) < 2:
            return []

        lines = []
        segments = _polyline_segments(self.centerline)

        # Estimate center cross-track to pick nearby indices
        nearest_cross = None
        for (ax, ay), (bx, by) in segments:
            _, proj_x, proj_y = _segment_projection(center_x, center_y, ax, ay, bx, by)
            dist = math.hypot(center_x - proj_x, center_y - proj_y)
            if nearest_cross is None or dist < nearest_cross[0]:
                cross = _segment_cross(center_x, center_y, ax, ay, bx, by)
                nearest_cross = (dist, cross)
        center_index = 0 if nearest_cross is None else round(nearest_cross[1] / self.swath_width)
        num_lines = int(render_distance / self.swath_width) + 2

        for i in range(center_index - num_lines, center_index + num_lines + 1):
            offset = i * self.swath_width
            for (ax, ay), (bx, by) in segments:
                seg_len = math.hypot(bx - ax, by - ay)
                if seg_len <= 1e-6:
                    continue
                perp_x = (by - ay) / seg_len
                perp_y = -(bx - ax) / seg_len
                x1 = ax + perp_x * offset
                y1 = ay + perp_y * offset
                x2 = bx + perp_x * offset
                y2 = by + perp_y * offset

                if math.hypot(center_x - (x1 + x2) / 2, center_y - (y1 + y2) / 2) > render_distance * 1.5:
                    continue

                lines.append((x1, y1, x2, y2, i == self.active_line_index))

        return lines


class HeadlandGuidance:
    """
    Headland guidance based on a boundary polygon and offset rings.
    """

    def __init__(self, boundary: List[Point2D], spacing: float = 6.0):
        self.boundary = boundary
        self.spacing = spacing

        self.cross_track_error = 0.0
        self.active_ring_index = 0

    def _signed_distance_to_boundary(self, x: float, y: float) -> float:
        if len(self.boundary) < 3:
            return 0.0
        min_dist = float("inf")
        for (ax, ay), (bx, by) in _polyline_segments(self.boundary + [self.boundary[0]]):
            _, proj_x, proj_y = _segment_projection(x, y, ax, ay, bx, by)
            dist = math.hypot(x - proj_x, y - proj_y)
            min_dist = min(min_dist, dist)

        # Point-in-polygon test for sign
        inside = False
        points = self.boundary
        j = len(points) - 1
        for i, (xi, yi) in enumerate(points):
            xj, yj = points[j]
            intersect = ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi)
            if intersect:
                inside = not inside
            j = i

        return -min_dist if inside else min_dist

    def update(self, pose: Pose) -> None:
        signed_distance = self._signed_distance_to_boundary(pose.x, pose.y)
        self.active_ring_index = round(signed_distance / self.spacing)
        self.cross_track_error = signed_distance - self.active_ring_index * self.spacing

    def get_visible_lines(self, center_x: float, center_y: float,
                          render_distance: float) -> List[Tuple[float, float, float, float, bool]]:
        if len(self.boundary) < 3:
            return []

        max_rings = int(render_distance / self.spacing) + 1
        lines = []
        for ring in range(-max_rings, max_rings + 1):
            offset = ring * self.spacing
            ring_points = _offset_polygon(self.boundary, offset)
            if len(ring_points) < 3:
                continue
            ring_points.append(ring_points[0])
            for (ax, ay), (bx, by) in _polyline_segments(ring_points):
                mid_x = (ax + bx) / 2
                mid_y = (ay + by) / 2
                if math.hypot(center_x - mid_x, center_y - mid_y) > render_distance * 1.5:
                    continue
                lines.append((ax, ay, bx, by, ring == self.active_ring_index))
        return lines
