"""
PyGame Simulator for Agricultural Guidance

A Python-based simulation for testing localizer and guidance algorithms
before implementing in Swift. Includes ISOXML support for task/field management.
"""

from .sensord import NMEASimulator, GNSSFix
from .localizer import Localizer, MachineGeometry, ImplementGeometry, Pose
from .guidance import ABGuidance, ABLine, CurvedABGuidance, HeadlandGuidance
from .vehicle import VehicleSimulator, VehicleState
from .renderer import Renderer
from .logger import CSVLogger

# ISOXML support
from .isoxml import (
    DatabaseManager,
    ISOXMLParser,
    ISOXMLExporter,
    EntityType,
    TaskType,
    TaskStatus,
    GuidanceLineType,
    DeviceType,
    ProductType,
    BoundaryPoint,
    GuidancePoint,
    ISOCustomer,
    ISOFarmer,
    ISOFarm,
    ISOPartfield,
    ISOGuidanceLine,
    ISOHeadland,
    ISOTask,
    ISODevice,
    ISOProduct,
)

__all__ = [
    # Simulation
    'NMEASimulator', 'GNSSFix',
    'Localizer', 'MachineGeometry', 'ImplementGeometry', 'Pose',
    'ABGuidance', 'ABLine', 'CurvedABGuidance', 'HeadlandGuidance',
    'VehicleSimulator', 'VehicleState',
    'Renderer',
    'CSVLogger',
    # ISOXML
    'DatabaseManager', 'ISOXMLParser', 'ISOXMLExporter',
    'EntityType', 'TaskType', 'TaskStatus', 'GuidanceLineType', 'DeviceType', 'ProductType',
    'BoundaryPoint', 'GuidancePoint',
    'ISOCustomer', 'ISOFarmer', 'ISOFarm', 'ISOPartfield',
    'ISOGuidanceLine', 'ISOHeadland', 'ISOTask', 'ISODevice', 'ISOProduct',
]
