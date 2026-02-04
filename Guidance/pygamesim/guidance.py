"""
AB Line Guidance System

Provides cross-track error and heading error for AB line guidance.
"""

import math
from dataclasses import dataclass
from typing import List, Optional, Tuple

from .localizer import Pose


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
