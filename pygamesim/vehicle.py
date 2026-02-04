"""
Vehicle Simulator - Ground truth vehicle dynamics

Simulates tractor with bicycle model dynamics.
"""

import math
from dataclasses import dataclass


@dataclass
class VehicleState:
    """Vehicle state."""
    x: float = 0.0
    y: float = 0.0
    heading: float = 0.0  # radians, 0=North, clockwise positive
    speed: float = 0.0    # m/s
    steering_angle: float = 0.0  # radians


class VehicleSimulator:
    """
    Simulates tractor dynamics using bicycle model.
    """

    def __init__(self, wheelbase: float = 2.5):
        self.wheelbase = wheelbase
        self.state = VehicleState()

        # Control inputs
        self.throttle = 0.0      # -1 to 1
        self.steering_input = 0.0  # -1 to 1

        # Control limits
        self.target_speed = 5.0   # m/s target when holding throttle
        self.max_speed = 15.0     # m/s (~54 km/h)
        self.max_steering = math.radians(35)  # 35 degrees

        # Control rates
        self.acceleration = 1.0   # m/s^2
        self.deceleration = 1.0   # m/s^2
        self.steering_rate = math.radians(45)  # deg/s

    def set_position(self, x: float, y: float, heading: float) -> None:
        """Set vehicle position."""
        self.state.x = x
        self.state.y = y
        self.state.heading = heading

    def update(self, dt: float) -> None:
        """Update vehicle state."""
        # Update speed based on throttle - accelerate toward target speed
        if self.throttle > 0:
            if self.state.speed < self.target_speed:
                self.state.speed += self.acceleration * dt
                self.state.speed = min(self.state.speed, self.target_speed)
        elif self.throttle < 0:
            # Brake
            self.state.speed -= self.deceleration * dt
        else:
            # Coast to stop at same deceleration rate
            if self.state.speed > 0:
                self.state.speed -= self.deceleration * dt

        self.state.speed = max(0.0, min(self.max_speed, self.state.speed))

        # Update steering
        target_steering = self.steering_input * self.max_steering
        steering_diff = target_steering - self.state.steering_angle
        max_change = self.steering_rate * dt
        if abs(steering_diff) > max_change:
            self.state.steering_angle += max_change * (1 if steering_diff > 0 else -1)
        else:
            self.state.steering_angle = target_steering

        # Bicycle model kinematics
        if abs(self.state.steering_angle) > 0.001:
            turn_radius = self.wheelbase / math.tan(self.state.steering_angle)
            angular_velocity = self.state.speed / turn_radius
        else:
            angular_velocity = 0.0

        # Update position and heading
        self.state.heading += angular_velocity * dt
        self.state.x += self.state.speed * math.sin(self.state.heading) * dt
        self.state.y += self.state.speed * math.cos(self.state.heading) * dt

        # Normalize heading to [-pi, pi]
        while self.state.heading > math.pi:
            self.state.heading -= 2 * math.pi
        while self.state.heading < -math.pi:
            self.state.heading += 2 * math.pi

    def get_antenna_position(self, antenna_offset: float) -> tuple:
        """Get antenna position given offset from rear axle."""
        ant_x = self.state.x + math.sin(self.state.heading) * antenna_offset
        ant_y = self.state.y + math.cos(self.state.heading) * antenna_offset
        return ant_x, ant_y
