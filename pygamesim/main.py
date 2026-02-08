"""
Main entry point for localizer demo.

Usage:
    python -m pygamesim.main
    python -m pygamesim.main --isoxml path/to/taskdata.zip

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
    I: Load ISOXML file (opens file dialog)
    Q/ESC: Quit
"""

import argparse
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
from .isoxml.parser import ISOXMLParser
from .isoxml.models import GuidanceLineType


def load_isoxml_guidance(filepath: str) -> tuple:
    """
    Load guidance and boundary from ISOXML file.

    Returns:
        tuple: (guidance_line, origin_lat, origin_lon, swath_width, boundary_local)
               or (None, None, None, None, None)
    """
    print(f"Loading ISOXML from: {filepath}")
    parser = ISOXMLParser()

    try:
        result = parser.parse_file(filepath, import_to_db=False)
        print(f"Parsed: {result.get('partfields', 0)} partfields, {result.get('guidance_lines', 0)} guidance lines")

        origin_lat = None
        origin_lon = None
        swath_width = 6.0
        gl = None
        boundary_local = None

        # Find guidance lines first to get origin
        if parser.guidance_lines:
            gl_id, gl = next(iter(parser.guidance_lines.items()))
            print(f"Found guidance line: {gl_id}, type={gl.type}, points={len(gl.points)}")

            if gl.points and len(gl.points) >= 2:
                # Use first point as origin
                origin_lat = gl.points[0].latitude
                origin_lon = gl.points[0].longitude
                swath_width = gl.spacing_m if gl.spacing_m else 6.0

                print(f"Origin: ({origin_lat:.6f}, {origin_lon:.6f})")
                print(f"Swath width: {swath_width}m")
                if gl.heading_deg:
                    print(f"Heading: {gl.heading_deg}°")

        # Find partfield boundary
        if parser.partfields and origin_lat is not None:
            pf_id, pf = next(iter(parser.partfields.items()))
            print(f"Found partfield: {pf_id}, name={pf.name}")

            if pf.boundary and len(pf.boundary) >= 3:
                print(f"Boundary has {len(pf.boundary)} points")
                # Convert boundary to local coordinates
                boundary_local = []
                for bp in pf.boundary:
                    local = bp.to_local(origin_lat, origin_lon)
                    boundary_local.append(local)
                print(f"Boundary converted to local coordinates")

        if gl is None:
            print("No guidance lines found in ISOXML file")
            return None, None, None, None, None

        return gl, origin_lat, origin_lon, swath_width, boundary_local

    except Exception as e:
        print(f"Error loading ISOXML: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None, None, None


def setup_guidance_from_isoxml(guidance: ABGuidance, gl, origin_lat: float, origin_lon: float):
    """Set up ABGuidance from ISOXML guidance line."""
    if not gl or not gl.points or len(gl.points) < 2:
        return False

    # Convert WGS84 to local coordinates
    local_points = gl.get_local_points(origin_lat, origin_lon)

    if gl.type == GuidanceLineType.STRAIGHT_AB or len(local_points) == 2:
        # Straight AB line
        ax, ay = local_points[0]
        bx, by = local_points[1]

        guidance.set_a_point(ax, ay)
        guidance.set_b_point(bx, by)

        print(f"AB Line set: A=({ax:.2f}, {ay:.2f}), B=({bx:.2f}, {by:.2f})")
        if guidance.ab_line and guidance.ab_line.is_valid:
            print(f"Heading: {math.degrees(guidance.ab_line.heading):.1f}°, Length: {guidance.ab_line.length:.1f}m")
        return True
    else:
        # Curved AB line (would need CurvedABGuidance)
        print(f"Curved guidance with {len(local_points)} points - using first 2 as AB")
        ax, ay = local_points[0]
        bx, by = local_points[-1]
        guidance.set_a_point(ax, ay)
        guidance.set_b_point(bx, by)
        return True


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Agricultural Guidance Simulator")
    parser.add_argument("--isoxml", "-i", type=str, help="Path to ISOXML TaskData file (.xml or .zip)")
    parser.add_argument("--swath", "-s", type=float, default=6.0, help="Swath width in meters (default: 6.0)")
    args = parser.parse_args()

    # Configuration
    swath_width = args.swath
    machine_geom = MachineGeometry(
        antenna_pivot=1.0,
        hitch_length=1.5
    )

    implement_geom = ImplementGeometry(
        pivot_offset=5.0,
        width=swath_width,
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

    # Load ISOXML if provided
    if args.isoxml:
        gl, origin_lat, origin_lon, iso_swath, boundary_local = load_isoxml_guidance(args.isoxml)
        if gl:
            if iso_swath:
                guidance.swath_width = iso_swath
                implement_geom.width = iso_swath
            setup_guidance_from_isoxml(guidance, gl, origin_lat, origin_lon)
            if boundary_local:
                renderer.set_boundary(boundary_local)
                print(f"Field boundary loaded with {len(boundary_local)} points")
            print("ISOXML guidance loaded successfully!")

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
                elif event.key == pygame.K_i:
                    # Load ISOXML file interactively
                    try:
                        import tkinter as tk
                        from tkinter import filedialog
                        root = tk.Tk()
                        root.withdraw()
                        filepath = filedialog.askopenfilename(
                            title="Select ISOXML TaskData file",
                            filetypes=[
                                ("ISOXML files", "*.zip *.xml *.XML"),
                                ("ZIP files", "*.zip"),
                                ("XML files", "*.xml *.XML"),
                                ("All files", "*.*")
                            ]
                        )
                        root.destroy()
                        if filepath:
                            gl, origin_lat, origin_lon, iso_swath, boundary_local = load_isoxml_guidance(filepath)
                            if gl:
                                if iso_swath:
                                    guidance.swath_width = iso_swath
                                setup_guidance_from_isoxml(guidance, gl, origin_lat, origin_lon)
                                if boundary_local:
                                    renderer.set_boundary(boundary_local)
                                    print(f"Boundary loaded: {len(boundary_local)} points")
                                print("ISOXML guidance loaded!")
                    except ImportError:
                        print("tkinter not available - use --isoxml command line argument")

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
