"""
Renderer - Pygame visualization for localizer demo

Renders vehicle, implement, guidance lines, track vector, and debug info.
"""

import math
from typing import Optional, Tuple, List

import pygame

from .localizer import Localizer, MachineGeometry, ImplementGeometry
from .vehicle import VehicleSimulator
from .guidance import ABGuidance


class Renderer:
    """
    Pygame-based visualization.
    """

    def __init__(self, width: int = 1200, height: int = 800):
        self.width = width
        self.height = height

        pygame.init()
        self.screen = pygame.display.set_mode((width, height))
        pygame.display.set_caption("Localizer Demo - AB Guidance")

        # Try to load font
        try:
            self.font = pygame.font.SysFont('Monaco', 14)
            self.font_large = pygame.font.SysFont('Monaco', 18)
        except:
            self.font = None
            self.font_large = None

        # View settings
        self.scale = 10.0  # pixels per meter
        self.center_x = width // 2
        self.center_y = height // 2
        self.follow_vehicle = True
        self.heading_up = False  # When True, screen rotates to keep machine heading up

        # Current view state (set during render)
        self._view_center_x = 0.0
        self._view_center_y = 0.0
        self._view_rotation = 0.0  # radians

        # Colors
        self.colors = {
            'background': (40, 45, 50),
            'grid': (60, 65, 70),
            'grid_major': (80, 85, 90),
            'true_vehicle': (100, 200, 100),
            'measured_vehicle': (200, 100, 100),
            'implement': (100, 150, 255),
            'hitch': (255, 200, 100),
            'guidance_line': (255, 165, 0),
            'guidance_active': (50, 255, 50),
            'text': (200, 200, 200),
            'a_point': (255, 100, 100),
            'b_point': (100, 100, 255),
            'track_vector': (255, 200, 100),
            'boundary': (255, 165, 0),  # Orange for field boundary
            'boundary_fill': (255, 165, 0, 30),  # Semi-transparent fill
        }

        # Field boundary (list of (x, y) points in local coordinates)
        self.boundary_points: List[Tuple[float, float]] = []

    def world_to_screen(self, x: float, y: float,
                        view_center_x: float = None,
                        view_center_y: float = None) -> Tuple[int, int]:
        """Convert world coordinates to screen coordinates."""
        # Use stored view state if not provided
        if view_center_x is None:
            view_center_x = self._view_center_x
        if view_center_y is None:
            view_center_y = self._view_center_y

        # Translate to view center
        dx = x - view_center_x
        dy = y - view_center_y

        # Apply rotation if heading-up mode
        if self._view_rotation != 0.0:
            cos_r = math.cos(self._view_rotation)
            sin_r = math.sin(self._view_rotation)
            rx = dx * cos_r - dy * sin_r
            ry = dx * sin_r + dy * cos_r
            dx, dy = rx, ry

        screen_x = self.center_x + dx * self.scale
        screen_y = self.center_y - dy * self.scale  # Y flipped
        return int(screen_x), int(screen_y)

    def draw_grid(self, view_center_x: float, view_center_y: float) -> None:
        """Draw background grid."""
        grid_spacing = 10.0  # meters

        # Calculate visible range (expand for rotation)
        half_width = self.width / (2 * self.scale)
        half_height = self.height / (2 * self.scale)
        half_range = max(half_width, half_height) * 1.5

        start_x = int((view_center_x - half_range) / grid_spacing) * grid_spacing
        end_x = int((view_center_x + half_range) / grid_spacing + 1) * grid_spacing
        start_y = int((view_center_y - half_range) / grid_spacing) * grid_spacing
        end_y = int((view_center_y + half_range) / grid_spacing + 1) * grid_spacing

        # Draw vertical lines
        x = start_x
        while x <= end_x:
            sx1, sy1 = self.world_to_screen(x, start_y)
            sx2, sy2 = self.world_to_screen(x, end_y)
            color = self.colors['grid_major'] if int(x) % 50 == 0 else self.colors['grid']
            pygame.draw.line(self.screen, color, (sx1, sy1), (sx2, sy2), 1)
            x += grid_spacing

        # Draw horizontal lines
        y = start_y
        while y <= end_y:
            sx1, sy1 = self.world_to_screen(start_x, y)
            sx2, sy2 = self.world_to_screen(end_x, y)
            color = self.colors['grid_major'] if int(y) % 50 == 0 else self.colors['grid']
            pygame.draw.line(self.screen, color, (sx1, sy1), (sx2, sy2), 1)
            y += grid_spacing

    def draw_vehicle(self, x: float, y: float, heading: float,
                     color: Tuple[int, int, int],
                     size: float = 2.0) -> None:
        """Draw vehicle triangle."""
        # Triangle points (nose forward)
        nose = (x + math.sin(heading) * size, y + math.cos(heading) * size)
        left = (x - math.sin(heading) * size * 0.5 - math.cos(heading) * size * 0.5,
                y - math.cos(heading) * size * 0.5 + math.sin(heading) * size * 0.5)
        right = (x - math.sin(heading) * size * 0.5 + math.cos(heading) * size * 0.5,
                 y - math.cos(heading) * size * 0.5 - math.sin(heading) * size * 0.5)

        points = [
            self.world_to_screen(nose[0], nose[1]),
            self.world_to_screen(left[0], left[1]),
            self.world_to_screen(right[0], right[1]),
        ]
        pygame.draw.polygon(self.screen, color, points)

    def draw_track_vector(self, x: float, y: float, heading: float,
                          speed: float, yaw_rate: float, color: Tuple[int, int, int],
                          prediction_time: float = 2.0) -> None:
        """Draw track vector showing predicted position based on current trajectory."""
        if speed < 0.1:
            return  # Don't draw if nearly stationary

        # Generate arc points
        arc_points = []
        num_segments = 20

        for i in range(num_segments + 1):
            t = (i / num_segments) * prediction_time
            h = heading + yaw_rate * t

            if abs(yaw_rate) < 0.001:
                # Going straight
                px = x + math.sin(heading) * speed * t
                py = y + math.cos(heading) * speed * t
            else:
                # Turning - arc formula
                px = x + (speed / yaw_rate) * (math.cos(heading) - math.cos(h))
                py = y + (speed / yaw_rate) * (math.sin(h) - math.sin(heading))

            arc_points.append(self.world_to_screen(px, py))

        # Draw arc as connected line segments
        if len(arc_points) >= 2:
            pygame.draw.lines(self.screen, color, False, arc_points, 2)

        # Draw circle at end position
        if arc_points:
            pygame.draw.circle(self.screen, color, arc_points[-1], 8, 2)

    def draw_implement_tee(self, hitch_x: float, hitch_y: float,
                           impl_x: float, impl_y: float, impl_heading: float,
                           width: float,
                           active: bool = False) -> None:
        """Draw implement as T-bar (hitch to work point with crossbar)."""
        # Green when active, blue when inactive
        color = (0, 255, 0) if active else self.colors['implement']

        # Draw stem from hitch to implement center
        p1 = self.world_to_screen(hitch_x, hitch_y)
        p2 = self.world_to_screen(impl_x, impl_y)
        pygame.draw.line(self.screen, color, p1, p2, 3)

        # Draw hitch point
        hitch_screen = self.world_to_screen(hitch_x, hitch_y)
        pygame.draw.circle(self.screen, self.colors['hitch'], hitch_screen, 5)

        # Draw crossbar at implement center (perpendicular to implement heading)
        half_width = width / 2
        left_x = impl_x - math.cos(impl_heading) * half_width
        left_y = impl_y + math.sin(impl_heading) * half_width
        right_x = impl_x + math.cos(impl_heading) * half_width
        right_y = impl_y - math.sin(impl_heading) * half_width

        p_left = self.world_to_screen(left_x, left_y)
        p_right = self.world_to_screen(right_x, right_y)
        pygame.draw.line(self.screen, color, p_left, p_right, 4)

        # Draw implement center marker
        impl_screen = self.world_to_screen(impl_x, impl_y)
        pygame.draw.circle(self.screen, color, impl_screen, 4)

    def set_boundary(self, points: List[Tuple[float, float]]) -> None:
        """Set the field boundary points (local coordinates)."""
        self.boundary_points = points

    def draw_boundary(self) -> None:
        """Draw field boundary polygon."""
        if len(self.boundary_points) < 3:
            return

        # Convert to screen coordinates
        screen_points = [self.world_to_screen(x, y) for x, y in self.boundary_points]

        # Draw semi-transparent fill
        boundary_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        pygame.draw.polygon(boundary_surface, (255, 165, 0, 40), screen_points)
        self.screen.blit(boundary_surface, (0, 0))

        # Draw boundary outline
        pygame.draw.polygon(self.screen, self.colors['boundary'], screen_points, 2)

        # Draw vertices
        for point in screen_points:
            pygame.draw.circle(self.screen, self.colors['boundary'], point, 4)

    def draw_guidance_lines(self, guidance: ABGuidance) -> None:
        """Draw AB guidance lines."""
        if not guidance.ab_line or not guidance.ab_line.is_valid:
            return

        # Draw A and B points
        a_screen = self.world_to_screen(guidance.ab_line.a_x, guidance.ab_line.a_y)
        b_screen = self.world_to_screen(guidance.ab_line.b_x, guidance.ab_line.b_y)
        pygame.draw.circle(self.screen, self.colors['a_point'], a_screen, 8)
        pygame.draw.circle(self.screen, self.colors['b_point'], b_screen, 8)

        if self.font:
            a_text = self.font.render("A", True, (255, 255, 255))
            b_text = self.font.render("B", True, (255, 255, 255))
            self.screen.blit(a_text, (a_screen[0] - 4, a_screen[1] - 6))
            self.screen.blit(b_text, (b_screen[0] - 4, b_screen[1] - 6))

        # Get visible lines
        render_distance = max(self.width, self.height) / self.scale * 1.5
        lines = guidance.get_visible_lines(self._view_center_x, self._view_center_y, render_distance)

        for x1, y1, x2, y2, is_active in lines:
            color = self.colors['guidance_active'] if is_active else self.colors['guidance_line']
            width = 3 if is_active else 1

            p1 = self.world_to_screen(x1, y1)
            p2 = self.world_to_screen(x2, y2)
            pygame.draw.line(self.screen, color, p1, p2, width)

    def draw_guidance_bar(self, guidance: ABGuidance, localizer: Localizer) -> None:
        """Draw guidance bar at top of screen."""
        if not guidance.ab_line or not guidance.ab_line.is_valid:
            return

        bar_width = 400
        bar_height = 20
        bar_x = (self.width - bar_width) // 2
        bar_y = 10

        # Background
        pygame.draw.rect(self.screen, (60, 60, 60),
                        (bar_x, bar_y, bar_width, bar_height))

        # Center line
        center_x = bar_x + bar_width // 2
        pygame.draw.line(self.screen, (100, 100, 100),
                        (center_x, bar_y), (center_x, bar_y + bar_height), 2)

        # Indicator position
        bar_pos = guidance.get_guidance_bar_position(bar_width=10.0)
        indicator_x = center_x + int(bar_pos * bar_width // 2)
        indicator_x = max(bar_x + 5, min(bar_x + bar_width - 5, indicator_x))

        # Indicator color
        error = abs(guidance.cross_track_error)
        if error < 0.1:
            indicator_color = (50, 255, 50)
        elif error < 0.5:
            indicator_color = (255, 255, 50)
        else:
            indicator_color = (255, 100, 50)

        pygame.draw.rect(self.screen, indicator_color,
                        (indicator_x - 4, bar_y + 2, 8, bar_height - 4))

        # Cross-track error text
        if self.font:
            xte_text = f"XTE: {guidance.cross_track_error:+.2f}m"
            text_surface = self.font.render(xte_text, True, self.colors['text'])
            self.screen.blit(text_surface, (bar_x + bar_width + 10, bar_y + 2))

    def draw_coverage(self, coverage_points: list) -> None:
        """Draw coverage paint (green 50% transparent).

        None entries in coverage_points indicate breaks (implement was turned off).
        """
        if len(coverage_points) < 2:
            return

        # Create a surface for transparent drawing
        coverage_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # Draw coverage strips between consecutive points
        for i in range(1, len(coverage_points)):
            # Skip if either point is None (break marker)
            if coverage_points[i - 1] is None or coverage_points[i] is None:
                continue

            x1, y1, h1, w1 = coverage_points[i - 1]
            x2, y2, h2, w2 = coverage_points[i]

            half_w = w1 / 2

            # Previous point corners
            p1_left = (x1 - math.cos(h1) * half_w, y1 + math.sin(h1) * half_w)
            p1_right = (x1 + math.cos(h1) * half_w, y1 - math.sin(h1) * half_w)

            # Current point corners
            p2_left = (x2 - math.cos(h2) * half_w, y2 + math.sin(h2) * half_w)
            p2_right = (x2 + math.cos(h2) * half_w, y2 - math.sin(h2) * half_w)

            # Convert to screen coordinates
            points = [
                self.world_to_screen(p1_left[0], p1_left[1]),
                self.world_to_screen(p1_right[0], p1_right[1]),
                self.world_to_screen(p2_right[0], p2_right[1]),
                self.world_to_screen(p2_left[0], p2_left[1]),
            ]

            # Draw green 50% transparent quad
            pygame.draw.polygon(coverage_surface, (0, 200, 0, 128), points)

        self.screen.blit(coverage_surface, (0, 0))

    def draw_debug_info(self, vehicle: VehicleSimulator, localizer: Localizer,
                        guidance: Optional[ABGuidance] = None,
                        implement_active: bool = False) -> None:
        """Draw debug information."""
        if not self.font:
            return

        lines = [
            f"Ground Truth: ({vehicle.state.x:.2f}, {vehicle.state.y:.2f}) h={math.degrees(vehicle.state.heading):.1f}°",
            f"Speed: {vehicle.state.speed:.2f} m/s ({vehicle.state.speed * 3.6:.1f} km/h)",
            f"",
            f"Localizer State:",
            f"  Instant speed: {localizer.last_instant_speed:.3f} m/s",
            f"  Filtered speed: {localizer.filtered_speed:.3f} m/s",
            f"  Spread: {localizer.last_spread:.4f}m",
            f"  Stationary: {localizer.last_is_stationary}",
            f"  Updating: {localizer.last_is_updating}",
            f"",
            f"Machine: ({localizer.machine_pose.x:.2f}, {localizer.machine_pose.y:.2f})",
            f"  Heading: {math.degrees(localizer.machine_pose.heading):.1f}°",
            f"Implement: ({localizer.implement_pose.x:.2f}, {localizer.implement_pose.y:.2f})",
            f"  Heading: {math.degrees(localizer.implement_pose.heading):.1f}°",
            f"  Active: {'ON (painting)' if implement_active else 'OFF'}",
            f"",
            f"View: {'Heading-Up' if self.heading_up else 'North-Up'}",
        ]

        if guidance and guidance.ab_line and guidance.ab_line.is_valid:
            lines.extend([
                f"",
                f"Guidance:",
                f"  XTE: {guidance.cross_track_error:+.3f}m",
                f"  Line: {guidance.active_line_index}",
                f"  Heading error: {math.degrees(guidance.heading_error):.1f}°",
            ])

        lines.extend([
            f"",
            f"Controls:",
            f"  Arrows/WASD: Drive",
            f"  SPACE: Implement on/off",
            f"  H: Heading-up mode",
            f"  1/2: A/B points, R: Reset",
        ])

        y = 50
        for line in lines:
            text_surface = self.font.render(line, True, self.colors['text'])
            self.screen.blit(text_surface, (10, y))
            y += 18

    def render(self, vehicle: VehicleSimulator,
               localizer: Localizer,
               machine_geom: MachineGeometry,
               implement_geom: ImplementGeometry,
               guidance: Optional[ABGuidance] = None,
               coverage_points: list = None,
               implement_active: bool = False) -> None:
        """Render the full scene."""
        self.screen.fill(self.colors['background'])

        # Determine view center
        if self.follow_vehicle:
            view_center_x = localizer.machine_pose.x
            view_center_y = localizer.machine_pose.y
        else:
            view_center_x = 0
            view_center_y = 0

        # Set view state for world_to_screen
        self._view_center_x = view_center_x
        self._view_center_y = view_center_y
        self._view_rotation = localizer.machine_pose.heading if self.heading_up else 0.0

        # Draw grid
        self.draw_grid(view_center_x, view_center_y)

        # Draw field boundary
        self.draw_boundary()

        # Draw coverage paint (before other elements)
        if coverage_points:
            self.draw_coverage(coverage_points)

        # Draw guidance lines
        if guidance:
            self.draw_guidance_lines(guidance)

        # Draw ground truth vehicle (semi-transparent)
        self.draw_vehicle(vehicle.state.x, vehicle.state.y, vehicle.state.heading,
                         self.colors['true_vehicle'], size=1.5)

        # Draw measured vehicle (localizer output)
        if localizer.is_initialized:
            # Calculate yaw rate from vehicle steering (bicycle model)
            yaw_rate = 0.0
            if abs(vehicle.state.steering_angle) > 0.001 and vehicle.state.speed > 0.1:
                turn_radius = vehicle.wheelbase / math.tan(vehicle.state.steering_angle)
                yaw_rate = vehicle.state.speed / turn_radius

            # Draw track vector first (behind vehicle)
            self.draw_track_vector(
                localizer.machine_pose.x, localizer.machine_pose.y,
                localizer.machine_pose.heading,
                localizer.filtered_speed,
                yaw_rate,
                self.colors['track_vector'],
                prediction_time=2.0
            )

            self.draw_vehicle(localizer.machine_pose.x, localizer.machine_pose.y,
                             localizer.machine_pose.heading,
                             self.colors['measured_vehicle'], size=2.0)

            # Draw implement T-bar (change color if active)
            self.draw_implement_tee(
                localizer.hitch_pose.x, localizer.hitch_pose.y,
                localizer.implement_pose.x, localizer.implement_pose.y,
                localizer.implement_pose.heading,
                implement_geom.width,
                active=implement_active
            )

        # Draw guidance bar
        if guidance:
            self.draw_guidance_bar(guidance, localizer)

        # Draw debug info
        self.draw_debug_info(vehicle, localizer, guidance, implement_active)

        pygame.display.flip()

    def cleanup(self) -> None:
        """Clean up pygame."""
        pygame.quit()
