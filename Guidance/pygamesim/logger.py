"""
Logger - CSV logging for localizer diagnostics

Logs all state at the GNSS update rate (10Hz).
"""

import csv
import os
from datetime import datetime
from typing import Optional

from .localizer import Localizer
from .vehicle import VehicleSimulator
from .guidance import ABGuidance


class CSVLogger:
    """
    Logs localizer and guidance state to CSV file.
    """

    def __init__(self, output_dir: str = "."):
        self.output_dir = output_dir
        self.file = None
        self.writer = None
        self.start_time = 0.0

    def start(self, filename: Optional[str] = None) -> str:
        """Start logging to a new file."""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"localizer_log_{timestamp}.csv"

        filepath = os.path.join(self.output_dir, filename)
        self.file = open(filepath, 'w', newline='')
        self.writer = csv.writer(self.file)

        # Write header
        self.writer.writerow([
            'time',
            # Ground truth
            'true_x', 'true_y', 'true_heading', 'true_speed',
            # GNSS
            'gnss_lat', 'gnss_lon', 'gnss_x', 'gnss_y',
            # Localizer state
            'instant_speed', 'filtered_speed', 'spread', 'is_stationary', 'is_updating',
            # Machine pose
            'machine_x', 'machine_y', 'machine_heading',
            # Hitch pose
            'hitch_x', 'hitch_y', 'hitch_heading',
            # Implement pose
            'impl_x', 'impl_y', 'impl_heading',
            # Guidance
            'cross_track_error', 'heading_error', 'active_line'
        ])

        self.start_time = 0.0
        return filepath

    def stop(self) -> None:
        """Stop logging and close file."""
        if self.file:
            self.file.close()
            self.file = None
            self.writer = None

    def log(self, current_time: float,
            vehicle: VehicleSimulator,
            gnss_lat: float, gnss_lon: float,
            gnss_x: float, gnss_y: float,
            localizer: Localizer,
            guidance: Optional[ABGuidance] = None) -> None:
        """Log a single frame of data."""
        if not self.writer:
            return

        if self.start_time == 0.0:
            self.start_time = current_time

        row = [
            f"{current_time - self.start_time:.3f}",
            # Ground truth
            f"{vehicle.state.x:.4f}",
            f"{vehicle.state.y:.4f}",
            f"{vehicle.state.heading:.4f}",
            f"{vehicle.state.speed:.3f}",
            # GNSS
            f"{gnss_lat:.8f}",
            f"{gnss_lon:.8f}",
            f"{gnss_x:.4f}",
            f"{gnss_y:.4f}",
            # Localizer state
            f"{localizer.last_instant_speed:.3f}",
            f"{localizer.filtered_speed:.3f}",
            f"{localizer.last_spread:.4f}",
            "1" if localizer.last_is_stationary else "0",
            "1" if localizer.last_is_updating else "0",
            # Machine pose
            f"{localizer.machine_pose.x:.4f}",
            f"{localizer.machine_pose.y:.4f}",
            f"{localizer.machine_pose.heading:.4f}",
            # Hitch pose
            f"{localizer.hitch_pose.x:.4f}",
            f"{localizer.hitch_pose.y:.4f}",
            f"{localizer.hitch_pose.heading:.4f}",
            # Implement pose
            f"{localizer.implement_pose.x:.4f}",
            f"{localizer.implement_pose.y:.4f}",
            f"{localizer.implement_pose.heading:.4f}",
            # Guidance
            f"{guidance.cross_track_error:.4f}" if guidance else "0",
            f"{guidance.heading_error:.4f}" if guidance else "0",
            str(guidance.active_line_index) if guidance else "0"
        ]

        self.writer.writerow(row)

    def flush(self) -> None:
        """Flush buffer to disk."""
        if self.file:
            self.file.flush()
