"""
ISOXML Data Models for pygamesim

Python dataclass implementations of ISOXML entities, aligned with ISO 11783 TaskData standard.
These models mirror the Swift ISOXMLModels for cross-platform compatibility.
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional, List, Dict, Any
import json
import math


# =============================================================================
# Enums
# =============================================================================


class EntityType(Enum):
    """Entity types for the IdTable - ISOXML ID prefixes"""
    CUSTOMER = "CTR"
    FARMER = "FRM"
    FARM = "FAR"
    PARTFIELD = "PFD"
    TASK = "TSK"
    DEVICE = "DVC"
    PRODUCT = "PDT"
    GUIDANCE_LINE = "GLN"
    HEADLAND = "HDL"


class TaskType(Enum):
    """Types of agricultural tasks"""
    PLANTING = "planting"
    SPRAYING = "spraying"
    FERTILIZING = "fertilizing"
    HARVESTING = "harvesting"
    TILLAGE = "tillage"
    SEEDING = "seeding"
    MOWING = "mowing"
    SCOUTING = "scouting"
    OTHER = "other"

    @property
    def display_name(self) -> str:
        return self.value.capitalize()


class TaskStatus(Enum):
    """Status of a task"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

    @property
    def display_name(self) -> str:
        return self.value.replace("_", " ").title()


class GuidanceLineType(Enum):
    """Guidance line types"""
    STRAIGHT_AB = "straight_ab"
    CURVED_AB = "curved_ab"


class DeviceType(Enum):
    """Device/implement types"""
    TRACTOR = "tractor"
    COMBINE = "combine"
    SPRAYER = "sprayer"
    SEEDER = "seeder"
    PLANTER = "planter"
    TILLAGE = "tillage"
    OTHER = "other"

    @property
    def display_name(self) -> str:
        if self == DeviceType.TILLAGE:
            return "Tillage Equipment"
        return self.value.capitalize()


class ProductType(Enum):
    """Product types"""
    SEED = "seed"
    FERTILIZER = "fertilizer"
    HERBICIDE = "herbicide"
    PESTICIDE = "pesticide"
    FUNGICIDE = "fungicide"
    OTHER = "other"

    @property
    def display_name(self) -> str:
        return self.value.capitalize()


# =============================================================================
# Point Types
# =============================================================================


@dataclass
class BoundaryPoint:
    """A single point in a field boundary polygon (WGS84)"""
    latitude: float
    longitude: float

    def to_dict(self) -> Dict[str, float]:
        return {"latitude": self.latitude, "longitude": self.longitude}

    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> "BoundaryPoint":
        return cls(latitude=data["latitude"], longitude=data["longitude"])

    def to_local(self, origin_lat: float, origin_lon: float) -> tuple:
        """Convert to local coordinates (meters) relative to origin"""
        meters = meters_per_degree(origin_lat)
        x = (self.longitude - origin_lon) * meters[0]
        y = (self.latitude - origin_lat) * meters[1]
        return (x, y)


@dataclass
class GuidancePoint:
    """A single point in a guidance line polyline (WGS84)"""
    latitude: float
    longitude: float

    def to_dict(self) -> Dict[str, float]:
        return {"latitude": self.latitude, "longitude": self.longitude}

    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> "GuidancePoint":
        return cls(latitude=data["latitude"], longitude=data["longitude"])

    def to_local(self, origin_lat: float, origin_lon: float) -> tuple:
        """Convert to local coordinates (meters) relative to origin"""
        meters = meters_per_degree(origin_lat)
        x = (self.longitude - origin_lon) * meters[0]
        y = (self.latitude - origin_lat) * meters[1]
        return (x, y)


# =============================================================================
# Device Configuration
# =============================================================================


@dataclass
class AntennaOffset:
    """Antenna offset configuration"""
    lateral: float = 0.0
    forward: float = 0.0
    height: float = 0.0

    def to_dict(self) -> Dict[str, float]:
        return {"lateral": self.lateral, "forward": self.forward, "height": self.height}

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AntennaOffset":
        return cls(
            lateral=data.get("lateral", 0.0),
            forward=data.get("forward", 0.0),
            height=data.get("height", 0.0)
        )


@dataclass
class DeviceConfig:
    """Device configuration (implements MachineProfile/ImplementProfile)"""
    wheelbase: Optional[float] = None
    work_width: Optional[float] = None
    antenna_offset: Optional[AntennaOffset] = None

    def to_dict(self) -> Dict[str, Any]:
        result = {}
        if self.wheelbase is not None:
            result["wheelbase"] = self.wheelbase
        if self.work_width is not None:
            result["work_width"] = self.work_width
        if self.antenna_offset is not None:
            result["antenna_offset"] = self.antenna_offset.to_dict()
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DeviceConfig":
        antenna = None
        if "antenna_offset" in data:
            antenna = AntennaOffset.from_dict(data["antenna_offset"])
        return cls(
            wheelbase=data.get("wheelbase"),
            work_width=data.get("work_width"),
            antenna_offset=antenna
        )


# =============================================================================
# Entity Models
# =============================================================================


@dataclass
class ISOCustomer:
    """Internal account identifier (not exposed to farmer)"""
    id: str
    name: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class ISOFarmer:
    """Represents a farmer user who creates farms and fields"""
    id: str
    customer_id: str
    last_name: str
    first_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @property
    def full_name(self) -> str:
        if self.first_name:
            return f"{self.first_name} {self.last_name}"
        return self.last_name


@dataclass
class ISOFarm:
    """Represents a farm entity owned by a farmer"""
    id: str
    farmer_id: str
    name: str
    address: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class ISOPartfield:
    """Represents a field (partfield) with boundary polygon"""
    id: str
    farm_id: str
    name: str
    area_m2: Optional[float] = None
    season: Optional[str] = None
    crop_type: Optional[str] = None
    notes: Optional[str] = None
    boundary: Optional[List[BoundaryPoint]] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @property
    def area_hectares(self) -> Optional[float]:
        if self.area_m2 is None:
            return None
        return self.area_m2 / 10000.0

    @property
    def area_acres(self) -> Optional[float]:
        if self.area_m2 is None:
            return None
        return self.area_m2 / 4046.86

    def calculate_area(self) -> Optional[float]:
        """Calculate area from boundary polygon using Shoelace formula"""
        if not self.boundary or len(self.boundary) < 3:
            return None

        # Get center latitude for meters conversion
        center_lat = sum(p.latitude for p in self.boundary) / len(self.boundary)
        meters = meters_per_degree(center_lat)

        # Convert to meters relative to first point
        origin = self.boundary[0]
        meters_points = [
            ((p.longitude - origin.longitude) * meters[0],
             (p.latitude - origin.latitude) * meters[1])
            for p in self.boundary
        ]

        # Shoelace formula
        n = len(meters_points)
        total = 0.0
        for i in range(n):
            j = (i + 1) % n
            total += meters_points[i][0] * meters_points[j][1]
            total -= meters_points[j][0] * meters_points[i][1]

        self.area_m2 = abs(total) / 2.0
        return self.area_m2

    def get_centroid(self) -> Optional[tuple]:
        """Get the centroid of the boundary polygon"""
        if not self.boundary or len(self.boundary) < 3:
            return None
        lat = sum(p.latitude for p in self.boundary) / len(self.boundary)
        lon = sum(p.longitude for p in self.boundary) / len(self.boundary)
        return (lat, lon)


@dataclass
class ISOGuidanceLine:
    """Guidance line (AB or curved) for field navigation"""
    id: str
    partfield_id: str
    type: GuidanceLineType
    points: List[GuidancePoint]
    spacing_m: float
    heading_deg: Optional[float] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    def get_local_points(self, origin_lat: float, origin_lon: float) -> List[tuple]:
        """Convert points to local coordinates relative to origin"""
        return [p.to_local(origin_lat, origin_lon) for p in self.points]


@dataclass
class ISOHeadland:
    """Headland boundary for turn management"""
    id: str
    partfield_id: str
    boundary: List[BoundaryPoint]
    offset_m: float
    direction: str = "inward"  # inward or outward
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    def get_local_boundary(self, origin_lat: float, origin_lon: float) -> List[tuple]:
        """Convert boundary to local coordinates relative to origin"""
        return [p.to_local(origin_lat, origin_lon) for p in self.boundary]


@dataclass
class ISOTask:
    """Represents a task performed on a partfield"""
    id: str
    partfield_id: str
    name: str
    task_type: TaskType
    status: TaskStatus = TaskStatus.PENDING
    device_id: Optional[str] = None
    product_id: Optional[str] = None
    guidance_line_id: Optional[str] = None
    headland_id: Optional[str] = None
    notes: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class ISODevice:
    """Represents a device (tractor, implement, etc.)"""
    id: str
    name: str
    device_type: DeviceType
    config: Optional[DeviceConfig] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class ISOProduct:
    """Represents a product (seed, fertilizer, chemical, etc.)"""
    id: str
    name: str
    product_type: ProductType
    unit: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


@dataclass
class TaskLogEntry:
    """A single log entry for a task (position + data)"""
    id: int
    task_id: str
    timestamp: datetime
    latitude: float
    longitude: float
    heading: Optional[float] = None
    speed: Optional[float] = None
    data: Optional[Dict[str, Any]] = None


@dataclass
class CoverageCell:
    """Coverage grid cell for tracking work completion"""
    id: int
    task_id: str
    row: int
    col: int
    timestamp: datetime


# =============================================================================
# Utility Functions
# =============================================================================


def meters_per_degree(latitude: float) -> tuple:
    """
    Calculate meters per degree at a given latitude.
    Returns (meters_per_degree_longitude, meters_per_degree_latitude)
    """
    lat_rad = math.radians(latitude)
    # WGS84 ellipsoid
    a = 6378137.0  # semi-major axis
    b = 6356752.314245  # semi-minor axis
    e_sq = 1 - (b * b) / (a * a)

    # Radius of curvature in meridian
    sin_lat = math.sin(lat_rad)
    cos_lat = math.cos(lat_rad)
    denom = math.sqrt(1 - e_sq * sin_lat * sin_lat)

    m_per_deg_lat = math.pi * a * (1 - e_sq) / (180 * denom ** 3)
    m_per_deg_lon = math.pi * a * cos_lat / (180 * denom)

    return (m_per_deg_lon, m_per_deg_lat)


def local_to_wgs84(x: float, y: float, origin_lat: float, origin_lon: float) -> tuple:
    """Convert local coordinates (meters) back to WGS84"""
    meters = meters_per_degree(origin_lat)
    lat = origin_lat + y / meters[1]
    lon = origin_lon + x / meters[0]
    return (lat, lon)
