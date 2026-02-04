"""
Main entry point for localizer demo.

Usage:
    python -m pygamesim.main

Controls:
    Arrow keys / WASD: Drive
    SPACE: Toggle implement on/off (paints green when on)
    H: Toggle heading-up mode (screen rotates with vehicle)
    1: Set A point
    2: Set B point
    C: Clear AB line
    F: Toggle camera follow
    +/-: Zoom in/out
    L: Toggle logging
    R: Reset position
    Q/ESC: Quit
"""

import math
import sys
import time

import pygame

from .sensord import NMEASimulator
from .localizer import MachineGeometry, ImplementGeometry, Localizer
from .guidance import ABGuidance
from .vehicle import VehicleSimulator
from .renderer import Renderer
from .logger import CSVLogger


def main():
    # Configuration
    machine_geom = MachineGeometry(
        antenna_pivot=1.0,
        hitch_length=1.5
    )

    implement_geom = ImplementGeometry(
        pivot_offset=5.0,
        width=6.0,
        is_pivoting=True
    )

    # Create components
    vehicle = VehicleSimulator(wheelbase=2.5)
    gnss = NMEASimulator(update_rate_hz=10.0, cep_meters=0.1)
    localizer = Localizer(machine_geom, implement_geom)
    guidance = ABGuidance(swath_width=implement_geom.width)
    renderer = Renderer(width=1200, height=800)
    logger = CSVLogger(output_dir=".")
    logging_enabled = False

    # Implement state and coverage
    implement_active = False
    coverage_points = []  # List of (x, y, heading, width) for paint strips

    # Timing
    clock = pygame.time.Clock()
    target_fps = 60
    sim_time = 0.0

    running = True
    print("Localizer Demo Started")
    print("Controls: Arrows/WASD=drive, SPACE=implement on/off, H=heading-up, 1/2=A/B points, R=Reset, Q=Quit")

    while running:
        dt = clock.get_time() / 1000.0
        if dt > 0.1:
            dt = 0.1  # Cap delta time

        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE or event.key == pygame.K_q:
                    running = False
                elif event.key == pygame.K_1:
                    # Set A point
                    if localizer.is_initialized:
                        guidance.set_a_point(localizer.machine_pose.x, localizer.machine_pose.y)
                        print(f"A point set at ({localizer.machine_pose.x:.2f}, {localizer.machine_pose.y:.2f})")
                    else:
                        print("Cannot set A - start moving first to initialize localizer")
                elif event.key == pygame.K_2:
                    # Set B point
                    if localizer.is_initialized and guidance.ab_line:
                        guidance.set_b_point(localizer.machine_pose.x, localizer.machine_pose.y)
                        print(f"B point set at ({localizer.machine_pose.x:.2f}, {localizer.machine_pose.y:.2f})")
                        if guidance.ab_line.is_valid:
                            print(f"AB line active: heading={math.degrees(guidance.ab_line.heading):.1f}°, length={guidance.ab_line.length:.1f}m")
                    else:
                        print("Set A point first (press 1)")
                elif event.key == pygame.K_c:
                    guidance.clear()
                    print("AB line cleared")
                elif event.key == pygame.K_f:
                    renderer.follow_vehicle = not renderer.follow_vehicle
                    print(f"Follow: {renderer.follow_vehicle}")
                elif event.key == pygame.K_h:
                    renderer.heading_up = not renderer.heading_up
                    print(f"Heading-up: {renderer.heading_up}")
                elif event.key == pygame.K_EQUALS or event.key == pygame.K_PLUS:
                    renderer.scale *= 1.2
                    print(f"Zoom: {renderer.scale:.1f}")
                elif event.key == pygame.K_MINUS:
                    renderer.scale /= 1.2
                    print(f"Zoom: {renderer.scale:.1f}")
                elif event.key == pygame.K_l:
                    if logging_enabled:
                        logger.stop()
                        logging_enabled = False
                        print("Logging stopped")
                    else:
                        filepath = logger.start()
                        logging_enabled = True
                        print(f"Logging to: {filepath}")
                elif event.key == pygame.K_r:
                    # Reset position
                    vehicle.set_position(0, 0, 0)
                    vehicle.state.speed = 0
                    localizer.is_initialized = False
                    localizer.position_history.clear()
                    guidance.clear()
                    coverage_points.clear()
                    implement_active = False
                    print("Position reset")
                elif event.key == pygame.K_SPACE:
                    # Toggle implement on/off
                    if implement_active:
                        # Turning off - add break marker to coverage
                        coverage_points.append(None)
                    implement_active = not implement_active
                    print(f"Implement: {'ON - painting' if implement_active else 'OFF'}")

        # Handle continuous key presses (arrow keys like original)
        keys = pygame.key.get_pressed()

        # Throttle
        if keys[pygame.K_UP] or keys[pygame.K_w]:
            vehicle.throttle = 1.0
        elif keys[pygame.K_DOWN] or keys[pygame.K_s]:
            vehicle.throttle = -1.0
        else:
            vehicle.throttle = 0.0

        # Steering
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            vehicle.steering_input = -1.0
        elif keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            vehicle.steering_input = 1.0
        else:
            vehicle.steering_input = 0.0

        # Update simulation
        vehicle.update(dt)
        sim_time += dt

        # Get antenna position and generate GNSS fix
        antenna_x, antenna_y = vehicle.get_antenna_position(machine_geom.antenna_pivot)
        fix = gnss.update(antenna_x, antenna_y, sim_time)

        if fix:
            # Update localizer
            localizer.update(fix, sim_time)

            # Update guidance
            if guidance.ab_line:
                guidance.update(localizer.implement_pose)

            # Record coverage when implement is active and moving
            if implement_active and localizer.filtered_speed > 0.3:
                coverage_points.append((
                    localizer.implement_pose.x,
                    localizer.implement_pose.y,
                    localizer.implement_pose.heading,
                    implement_geom.width
                ))

            # Log data
            if logging_enabled:
                gnss_x, gnss_y = localizer.wgs84_to_local(fix.latitude, fix.longitude)
                logger.log(sim_time, vehicle, fix.latitude, fix.longitude,
                          gnss_x, gnss_y, localizer, guidance)

        # Render
        renderer.render(vehicle, localizer, machine_geom, implement_geom, guidance,
                       coverage_points, implement_active)

        # Maintain frame rate
        clock.tick(target_fps)

    # Cleanup
    if logging_enabled:
        logger.stop()
    renderer.cleanup()
    print("Demo ended")


if __name__ == "__main__":
    main()
