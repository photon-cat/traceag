"""
Automated test for localizer - drives forward then in a circle and logs CSV.

Usage:
    python -m pygamesim.test_localizer
"""

import math
import os
import sys

from .sensord import NMEASimulator
from .localizer import MachineGeometry, ImplementGeometry, Localizer
from .guidance import ABGuidance
from .vehicle import VehicleSimulator
from .logger import CSVLogger


def run_test(output_filename: str = "test_localizer.csv") -> str:
    """
    Run automated test:
    1. Stay stationary for 3 seconds
    2. Drive forward for 5 seconds
    3. Drive in a circle (left turn) for 8 seconds
    4. Stop and stay stationary for 2 seconds

    Returns the path to the generated CSV file.
    """
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

    output_dir = os.path.dirname(os.path.abspath(__file__))
    logger = CSVLogger(output_dir=output_dir)
    filepath = logger.start(output_filename)

    # Simulation parameters
    dt = 0.016  # ~60 FPS
    sim_time = 0.0

    # Test phases
    phases = [
        ("stationary_start", 3.0, 0.0, 0.0),   # (name, duration, throttle, steering)
        ("forward", 5.0, 1.0, 0.0),             # Drive forward
        ("circle", 8.0, 1.0, 0.7),              # Turn left in circle
        ("stationary_end", 2.0, 0.0, 0.0),      # Stop
    ]

    current_phase = 0
    phase_start_time = 0.0

    print(f"Running localizer test, logging to: {filepath}")

    total_duration = sum(p[1] for p in phases)

    while sim_time < total_duration:
        # Determine current phase
        phase_name, phase_duration, throttle, steering = phases[current_phase]
        phase_elapsed = sim_time - phase_start_time

        if phase_elapsed >= phase_duration:
            # Move to next phase
            current_phase += 1
            if current_phase >= len(phases):
                break
            phase_start_time = sim_time
            phase_name, phase_duration, throttle, steering = phases[current_phase]
            print(f"  t={sim_time:.1f}s: Phase '{phase_name}'")

        # Apply controls
        vehicle.throttle = throttle
        vehicle.steering_input = steering

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

            # Log data
            gnss_x, gnss_y = localizer.wgs84_to_local(fix.latitude, fix.longitude)
            logger.log(sim_time, vehicle, fix.latitude, fix.longitude,
                      gnss_x, gnss_y, localizer, guidance)

    logger.stop()
    print(f"Test complete. Logged {sim_time:.1f}s of data to {filepath}")
    return filepath


def analyze_csv(filepath: str) -> dict:
    """
    Analyze the CSV for potential bugs.

    Checks for:
    1. Jitter when stationary (position variance when not moving)
    2. Heading errors (difference between true and computed heading)
    3. Speed errors (filtered_speed vs true_speed)
    4. Position tracking error (machine pose vs true position)

    Returns dict with analysis results.
    """
    import csv

    results = {
        "issues": [],
        "stats": {}
    }

    rows = []
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    if not rows:
        results["issues"].append("ERROR: No data in CSV")
        return results

    print(f"\nAnalyzing {len(rows)} samples from {filepath}...")

    # 1. Check jitter when stationary
    stationary_rows = [r for r in rows if r['is_stationary'] == '1']
    if stationary_rows:
        machine_x_vals = [float(r['machine_x']) for r in stationary_rows]
        machine_y_vals = [float(r['machine_y']) for r in stationary_rows]

        if len(machine_x_vals) > 1:
            x_range = max(machine_x_vals) - min(machine_x_vals)
            y_range = max(machine_y_vals) - min(machine_y_vals)
            stationary_jitter = math.sqrt(x_range**2 + y_range**2)
            results["stats"]["stationary_jitter_m"] = stationary_jitter

            if stationary_jitter > 0.1:
                results["issues"].append(
                    f"HIGH JITTER when stationary: {stationary_jitter:.3f}m "
                    f"(should be <0.1m)"
                )
            else:
                print(f"  OK: Stationary jitter = {stationary_jitter:.4f}m")

    # 2. Check heading errors when moving
    moving_rows = [r for r in rows if r['is_updating'] == '1']
    if moving_rows:
        heading_errors = []
        for r in moving_rows:
            true_heading = float(r['true_heading'])
            machine_heading = float(r['machine_heading'])

            # Compute angular difference
            diff = machine_heading - true_heading
            while diff > math.pi:
                diff -= 2 * math.pi
            while diff < -math.pi:
                diff += 2 * math.pi
            heading_errors.append(abs(diff))

        avg_heading_error = sum(heading_errors) / len(heading_errors)
        max_heading_error = max(heading_errors)
        results["stats"]["avg_heading_error_deg"] = math.degrees(avg_heading_error)
        results["stats"]["max_heading_error_deg"] = math.degrees(max_heading_error)

        if avg_heading_error > math.radians(10):
            results["issues"].append(
                f"HIGH AVG HEADING ERROR: {math.degrees(avg_heading_error):.1f}deg "
                f"(should be <10deg)"
            )
        else:
            print(f"  OK: Avg heading error = {math.degrees(avg_heading_error):.2f}deg")

        if max_heading_error > math.radians(30):
            results["issues"].append(
                f"HIGH MAX HEADING ERROR: {math.degrees(max_heading_error):.1f}deg "
                f"(should be <30deg)"
            )
        else:
            print(f"  OK: Max heading error = {math.degrees(max_heading_error):.2f}deg")

    # 3. Check speed tracking when moving at constant speed
    # Look for rows where true_speed is ~5 m/s (target speed)
    constant_speed_rows = [r for r in rows if 4.5 < float(r['true_speed']) < 5.5]
    if constant_speed_rows:
        speed_errors = []
        for r in constant_speed_rows:
            true_speed = float(r['true_speed'])
            filtered_speed = float(r['filtered_speed'])
            speed_errors.append(abs(filtered_speed - true_speed))

        avg_speed_error = sum(speed_errors) / len(speed_errors)
        results["stats"]["avg_speed_error_mps"] = avg_speed_error

        if avg_speed_error > 1.0:
            results["issues"].append(
                f"HIGH SPEED ERROR: {avg_speed_error:.2f}m/s "
                f"(should be <1.0m/s)"
            )
        else:
            print(f"  OK: Avg speed error = {avg_speed_error:.3f}m/s")

    # 4. Check position tracking error
    moving_rows = [r for r in rows if float(r['true_speed']) > 1.0]
    if moving_rows:
        position_errors = []
        for r in moving_rows:
            true_x = float(r['true_x'])
            true_y = float(r['true_y'])
            machine_x = float(r['machine_x'])
            machine_y = float(r['machine_y'])

            # Machine is offset from true position by antenna_pivot in heading direction
            # so we compare to antenna position instead
            true_heading = float(r['true_heading'])
            expected_machine_x = true_x  # rear axle is at true position
            expected_machine_y = true_y

            error = math.sqrt((machine_x - expected_machine_x)**2 +
                            (machine_y - expected_machine_y)**2)
            position_errors.append(error)

        avg_pos_error = sum(position_errors) / len(position_errors)
        max_pos_error = max(position_errors)
        results["stats"]["avg_position_error_m"] = avg_pos_error
        results["stats"]["max_position_error_m"] = max_pos_error

        if avg_pos_error > 1.0:
            results["issues"].append(
                f"HIGH AVG POSITION ERROR: {avg_pos_error:.2f}m "
                f"(should be <1.0m)"
            )
        else:
            print(f"  OK: Avg position error = {avg_pos_error:.3f}m")

        if max_pos_error > 2.0:
            results["issues"].append(
                f"HIGH MAX POSITION ERROR: {max_pos_error:.2f}m "
                f"(should be <2.0m)"
            )
        else:
            print(f"  OK: Max position error = {max_pos_error:.3f}m")

    # 5. Check for instant_speed spikes when stationary
    stationary_rows = [r for r in rows if r['is_stationary'] == '1']
    if stationary_rows:
        instant_speeds = [float(r['instant_speed']) for r in stationary_rows]
        max_instant_when_stationary = max(instant_speeds) if instant_speeds else 0
        results["stats"]["max_instant_speed_when_stationary"] = max_instant_when_stationary

        # This is expected to be noisy due to GNSS, but filtered_speed should be 0
        filtered_speeds = [float(r['filtered_speed']) for r in stationary_rows]
        max_filtered_when_stationary = max(filtered_speeds) if filtered_speeds else 0

        if max_filtered_when_stationary > 0.1:
            results["issues"].append(
                f"FILTERED SPEED NOT ZERO WHEN STATIONARY: {max_filtered_when_stationary:.2f}m/s"
            )
        else:
            print(f"  OK: Filtered speed when stationary = {max_filtered_when_stationary:.3f}m/s")

    # Summary
    print(f"\n{'='*50}")
    if results["issues"]:
        print(f"FOUND {len(results['issues'])} ISSUES:")
        for issue in results["issues"]:
            print(f"  - {issue}")
    else:
        print("ALL CHECKS PASSED!")
    print(f"{'='*50}")

    return results


def main():
    """Run test and analyze results."""
    filepath = run_test()
    results = analyze_csv(filepath)

    # Return exit code based on issues found
    if results["issues"]:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
