"""
Localizer - Kinematic chain from antenna to implement

Computes machine and implement pose from GNSS fixes.
"""

import math
from dataclasses import dataclass, field
from typing import List, Optional

from .sensord import GNSSFix


@dataclass
class Pose:
    """2D pose with heading."""
    x: float = 0.0
    y: float = 0.0
    heading: float = 0.0  # radians, 0=North, clockwise positive


@dataclass
class MachineGeometry:
    """Machine geometry configuration."""
    antenna_pivot: float = 1.0      # Antenna to rear axle (pivot point)
    hitch_length: float = 1.5       # Rear axle to hitch point


@dataclass
class ImplementGeometry:
    """Implement geometry configuration."""
    pivot_offset: float = 5.0       # Hitch to implement work point
    width: float = 6.0              # Implement width
    is_pivoting: bool = True        # True for trailing, False for rigid


class Localizer:
    """
    Computes machine and implement pose from GNSS antenna position.

    Kinematic chain: Antenna -> Rear Axle (Machine) -> Hitch -> Implement
    """

    def __init__(self, machine: MachineGeometry, implement: ImplementGeometry):
        self.machine = machine
        self.implement = implement

        # Output poses
        self.antenna_pose = Pose()
        self.machine_pose = Pose()
        self.hitch_pose = Pose()
        self.implement_pose = Pose()

        # Internal state
        self.heading = 0.0
        self.is_initialized = False

        # Position history for heading calculation
        self.position_history: List[tuple] = []
        self.history_size = 20  # 2 seconds at 10Hz

        # Previous positions for velocity calculation
        self.prev_x = 0.0
        self.prev_y = 0.0
        self.prev_time = 0.0

        # Implement tracking
        self.prev_implement_x = 0.0
        self.prev_implement_y = 0.0

        # Velocity filtering
        self.filtered_speed = 0.0
        self.speed_filter_alpha = 0.1
        self.moving_sample_count = 0
        self.min_moving_samples = 20  # 2 sec at 10Hz

        # Thresholds
        self.min_speed_for_heading = 0.5  # m/s
        self.stationary_threshold = 0.5   # meters spread for stationary detection
        self.min_distance_for_heading = 0.3  # minimum distance moved to update heading (increased)
        self.heading_filter_alpha = 0.3  # heading smoothing (0=no update, 1=instant)
        self.heading_baseline_samples = 5  # use position from N samples ago for heading calc

        # Position filtering (EMA)
        self.filtered_x = 0.0
        self.filtered_y = 0.0
        self.position_filter_alpha = 0.3  # lower = smoother but more lag
        self.position_initialized = False

        # Frozen position when stationary
        self.frozen_x = 0.0
        self.frozen_y = 0.0
        self.was_stationary = False

        # Debug state
        self.last_instant_speed = 0.0
        self.last_spread = 0.0
        self.last_is_stationary = False
        self.last_is_updating = False

        # WGS84 conversion
        self.base_lat = 38.06517
        self.base_lon = -79.05179
        self.meters_per_deg_lat = 111132.92
        self.meters_per_deg_lon = 111132.92 * math.cos(math.radians(self.base_lat))

    def wgs84_to_local(self, lat: float, lon: float) -> tuple:
        """Convert WGS84 to local coordinates."""
        x = (lon - self.base_lon) * self.meters_per_deg_lon
        y = (lat - self.base_lat) * self.meters_per_deg_lat
        return x, y

    def update(self, fix: GNSSFix, current_time: float) -> None:
        """Update localizer with new GNSS fix."""
        # Convert to local coordinates
        raw_x, raw_y = self.wgs84_to_local(fix.latitude, fix.longitude)

        # Apply position filtering (EMA)
        if not self.position_initialized:
            self.filtered_x = raw_x
            self.filtered_y = raw_y
            self.position_initialized = True
        else:
            self.filtered_x += (raw_x - self.filtered_x) * self.position_filter_alpha
            self.filtered_y += (raw_y - self.filtered_y) * self.position_filter_alpha

        antenna_x = self.filtered_x
        antenna_y = self.filtered_y

        self.antenna_pose.x = antenna_x
        self.antenna_pose.y = antenna_y

        # Calculate instant velocity from filtered positions
        dt = current_time - self.prev_time if self.prev_time > 0 else 0.1
        if dt > 0:
            dx = antenna_x - self.prev_x
            dy = antenna_y - self.prev_y
            distance = math.sqrt(dx*dx + dy*dy)
            instant_speed = distance / dt
        else:
            instant_speed = 0.0
            distance = 0.0

        self.last_instant_speed = instant_speed

        # Filter velocity
        self.filtered_speed += (instant_speed - self.filtered_speed) * self.speed_filter_alpha

        # Track position history (use filtered positions)
        self.position_history.append((antenna_x, antenna_y))
        if len(self.position_history) > self.history_size:
            self.position_history.pop(0)

        # Calculate position spread for stationary detection
        is_stationary = False
        spread = 0.0
        if len(self.position_history) >= self.history_size:
            xs = [p[0] for p in self.position_history]
            ys = [p[1] for p in self.position_history]
            spread = math.sqrt((max(xs)-min(xs))**2 + (max(ys)-min(ys))**2)
            is_stationary = spread < self.stationary_threshold

        self.last_spread = spread
        self.last_is_stationary = is_stationary

        # Reset filtered speed when stationary (GNSS noise creates false ~1m/s)
        if is_stationary:
            self.filtered_speed = 0.0

        # Track moving samples
        if self.filtered_speed > self.min_speed_for_heading and not is_stationary:
            self.moving_sample_count += 1
        else:
            self.moving_sample_count = 0

        # Freeze/unfreeze position management
        if is_stationary:
            if not self.was_stationary:
                # Just became stationary - freeze current position
                self.frozen_x = antenna_x
                self.frozen_y = antenna_y
            # Use frozen position when stationary
            antenna_x = self.frozen_x
            antenna_y = self.frozen_y
        self.was_stationary = is_stationary

        # Use longer baseline for heading calculation (compare to position N samples ago)
        baseline_distance = 0.0
        baseline_dx = 0.0
        baseline_dy = 0.0
        if len(self.position_history) > self.heading_baseline_samples:
            old_pos = self.position_history[-self.heading_baseline_samples - 1]
            baseline_dx = antenna_x - old_pos[0]
            baseline_dy = antenna_y - old_pos[1]
            baseline_distance = math.sqrt(baseline_dx*baseline_dx + baseline_dy*baseline_dy)

        # Determine if we should update heading
        is_updating = (self.moving_sample_count >= self.min_moving_samples and
                       baseline_distance > self.min_distance_for_heading)
        self.last_is_updating = is_updating

        # Update heading from position delta with smoothing
        if is_updating:
            new_heading = math.atan2(baseline_dx, baseline_dy)

            if self.is_initialized:
                # Smooth heading update (handle wraparound)
                heading_diff = new_heading - self.heading
                while heading_diff > math.pi:
                    heading_diff -= 2 * math.pi
                while heading_diff < -math.pi:
                    heading_diff += 2 * math.pi
                self.heading += heading_diff * self.heading_filter_alpha
                # Normalize
                while self.heading > math.pi:
                    self.heading -= 2 * math.pi
                while self.heading < -math.pi:
                    self.heading += 2 * math.pi
            else:
                self.heading = new_heading
                self.is_initialized = True

        # Store for next iteration
        self.prev_x = self.filtered_x  # Use filtered for velocity calc
        self.prev_y = self.filtered_y
        self.prev_time = current_time

        # Update antenna pose heading
        self.antenna_pose.heading = self.heading

        # Machine pose (rear axle) - use potentially frozen position
        self.machine_pose.x = antenna_x - math.sin(self.heading) * self.machine.antenna_pivot
        self.machine_pose.y = antenna_y - math.cos(self.heading) * self.machine.antenna_pivot
        self.machine_pose.heading = self.heading

        # Hitch pose
        self.hitch_pose.x = self.machine_pose.x - math.sin(self.heading) * self.machine.hitch_length
        self.hitch_pose.y = self.machine_pose.y - math.cos(self.heading) * self.machine.hitch_length
        self.hitch_pose.heading = self.heading

        # Implement pose
        if self.implement.is_pivoting:
            # Only update implement heading when NOT stationary and actively updating
            if not is_stationary and is_updating:
                impl_dx = self.hitch_pose.x - self.prev_implement_x
                impl_dy = self.hitch_pose.y - self.prev_implement_y
                impl_dist = math.sqrt(impl_dx*impl_dx + impl_dy*impl_dy)

                if impl_dist > 0.1:  # Increased threshold
                    impl_heading = math.atan2(impl_dx, impl_dy)

                    # Jackknife protection
                    angle_diff = abs(math.pi - abs(abs(impl_heading - self.heading) - math.pi))
                    if angle_diff > 1.9:
                        impl_heading = self.heading

                    self.implement_pose.heading = impl_heading

                self.implement_pose.x = self.hitch_pose.x - math.sin(self.implement_pose.heading) * self.implement.pivot_offset
                self.implement_pose.y = self.hitch_pose.y - math.cos(self.implement_pose.heading) * self.implement.pivot_offset

                self.prev_implement_x = self.implement_pose.x
                self.prev_implement_y = self.implement_pose.y
            else:
                # Stationary - keep implement at last known position relative to hitch
                self.implement_pose.x = self.hitch_pose.x - math.sin(self.implement_pose.heading) * self.implement.pivot_offset
                self.implement_pose.y = self.hitch_pose.y - math.cos(self.implement_pose.heading) * self.implement.pivot_offset
        else:
            # Rigid implement
            self.implement_pose.x = self.hitch_pose.x - math.sin(self.heading) * self.implement.pivot_offset
            self.implement_pose.y = self.hitch_pose.y - math.cos(self.heading) * self.implement.pivot_offset
            self.implement_pose.heading = self.heading
