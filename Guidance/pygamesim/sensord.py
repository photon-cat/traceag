"""
GNSS Simulator - Simulates u-blox M8P RTK receiver

Generates noisy GNSS fixes at 10Hz with configurable CEP.
"""

import math
import random
from dataclasses import dataclass
from typing import Optional


@dataclass
class GNSSFix:
    """GNSS fix data."""
    latitude: float
    longitude: float
    altitude: float
    fix_quality: int  # 1=GPS, 4=RTK Fix, 5=RTK Float
    num_satellites: int
    hdop: float
    timestamp: float


class NMEASimulator:
    """
    Simulates GNSS receiver with realistic noise characteristics.

    Based on u-blox M8P RTK receiver specs:
    - Update rate: 10Hz
    - RTK accuracy: ~0.01m CEP (configured via cep_meters)
    """

    def __init__(self, update_rate_hz: float = 10.0, cep_meters: float = 0.0,
                 base_lat: float = 38.06517, base_lon: float = -79.05179):
        self.update_rate = update_rate_hz
        self.update_interval = 1.0 / update_rate_hz
        self.cep = cep_meters
        # Convert CEP to standard deviation (CEP = 1.177 * sigma for 2D Gaussian)
        self.sigma = cep_meters / 1.177

        # Base coordinates (origin of local frame)
        self.base_lat = base_lat
        self.base_lon = base_lon

        # Meters per degree at base latitude
        self.meters_per_deg_lat = 111132.92
        self.meters_per_deg_lon = 111132.92 * math.cos(math.radians(base_lat))

        # Timing
        self.last_fix_time = 0.0

        # Slow-varying bias (simulates multipath/atmospheric effects)
        self.bias_x = 0.0
        self.bias_y = 0.0
        self.bias_rate = 0.1  # How fast bias changes

    def update(self, true_x: float, true_y: float, current_time: float) -> Optional[GNSSFix]:
        """
        Generate a GNSS fix if enough time has passed.

        Args:
            true_x: True X position in local frame (meters, East)
            true_y: True Y position in local frame (meters, North)
            current_time: Current simulation time (seconds)

        Returns:
            GNSSFix if a new fix is available, None otherwise
        """
        if current_time - self.last_fix_time < self.update_interval:
            return None

        self.last_fix_time = current_time

        # Add noise to position (skip if CEP is 0)
        if self.cep > 0:
            # Update slow-varying bias
            self.bias_x += (random.gauss(0, 0.01) - self.bias_x * 0.1) * self.bias_rate
            self.bias_y += (random.gauss(0, 0.01) - self.bias_y * 0.1) * self.bias_rate

            noise_x = random.gauss(0, self.sigma) + self.bias_x
            noise_y = random.gauss(0, self.sigma) + self.bias_y

            measured_x = true_x + noise_x
            measured_y = true_y + noise_y
        else:
            measured_x = true_x
            measured_y = true_y

        # Convert to lat/lon
        lat = self.base_lat + measured_y / self.meters_per_deg_lat
        lon = self.base_lon + measured_x / self.meters_per_deg_lon

        return GNSSFix(
            latitude=lat,
            longitude=lon,
            altitude=400.0,
            fix_quality=4,  # RTK Fix
            num_satellites=12,
            hdop=0.8,
            timestamp=current_time
        )

    def generate_gga(self, fix: GNSSFix) -> str:
        """Generate NMEA GGA sentence from fix."""
        lat_deg = int(abs(fix.latitude))
        lat_min = (abs(fix.latitude) - lat_deg) * 60
        lat_dir = 'N' if fix.latitude >= 0 else 'S'

        lon_deg = int(abs(fix.longitude))
        lon_min = (abs(fix.longitude) - lon_deg) * 60
        lon_dir = 'E' if fix.longitude >= 0 else 'W'

        # Format time as HHMMSS.SS
        hours = int(fix.timestamp / 3600) % 24
        minutes = int(fix.timestamp / 60) % 60
        seconds = fix.timestamp % 60
        time_str = f"{hours:02d}{minutes:02d}{seconds:05.2f}"

        sentence = f"GPGGA,{time_str},{lat_deg:02d}{lat_min:07.4f},{lat_dir},"
        sentence += f"{lon_deg:03d}{lon_min:07.4f},{lon_dir},"
        sentence += f"{fix.fix_quality},{fix.num_satellites:02d},{fix.hdop:.1f},"
        sentence += f"{fix.altitude:.1f},M,0.0,M,,"

        # Calculate checksum
        checksum = 0
        for char in sentence:
            checksum ^= ord(char)

        return f"${sentence}*{checksum:02X}"
