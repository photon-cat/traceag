"""
ISOXML Parser for TaskData.xml

Parses ISO 11783-10 TaskData files into Python data models.
Supports reading from both raw XML files and TASKDATA.ZIP archives.
"""

import xml.etree.ElementTree as ET
import zipfile
import os
import math
from datetime import datetime
from typing import Optional, List, Dict, Any, Tuple, BinaryIO
from pathlib import Path

from .models import (
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
    DeviceConfig,
    AntennaOffset,
)
from .database import DatabaseManager


# ISOXML element tag to entity type mapping
ISOXML_TAGS = {
    "CTR": "Customer",
    "FRM": "Farm",
    "PFD": "Partfield",
    "TSK": "Task",
    "DVC": "Device",
    "PDT": "Product",
    "PLN": "Polygon",
    "LSG": "LineString",
    "PNT": "Point",
    "GGP": "GuidanceGroup",
    "GLN": "GuidanceLine",
    "GPN": "GuidancePattern",
    "ASP": "AllocationStamp",
    "TLG": "TimeLog",
}


class ISOXMLParser:
    """
    Parser for ISOXML TaskData files.

    Supports:
    - Reading from TASKDATA.XML files
    - Reading from TASKDATA.ZIP archives
    - Importing into DatabaseManager
    """

    def __init__(self, db: Optional[DatabaseManager] = None):
        """
        Initialize parser.

        Args:
            db: Optional DatabaseManager for storing parsed data.
                If None, creates temporary in-memory structures.
        """
        self.db = db

        # Parsed entities (for cases where db is not used)
        self.customers: Dict[str, ISOCustomer] = {}
        self.farms: Dict[str, ISOFarm] = {}
        self.partfields: Dict[str, ISOPartfield] = {}
        self.tasks: Dict[str, ISOTask] = {}
        self.devices: Dict[str, ISODevice] = {}
        self.products: Dict[str, ISOProduct] = {}
        self.guidance_lines: Dict[str, ISOGuidanceLine] = {}
        self.headlands: Dict[str, ISOHeadland] = {}

        # ID mapping for external -> internal IDs
        self._id_map: Dict[str, str] = {}

        # Base directory for external file references
        self._base_dir: Optional[str] = None

    def parse_file(self, path: str, import_to_db: bool = True) -> Dict[str, Any]:
        """
        Parse a TASKDATA.XML or TASKDATA.ZIP file.

        Args:
            path: Path to the file
            import_to_db: If True and db is set, import to database

        Returns:
            Dictionary with parsed entity counts
        """
        path = Path(path)

        if path.suffix.lower() == ".zip":
            return self._parse_zip(str(path), import_to_db)
        elif path.suffix.lower() == ".xml":
            self._base_dir = str(path.parent)
            with open(path, "rb") as f:
                return self._parse_xml(f, import_to_db)
        else:
            raise ValueError(f"Unsupported file type: {path.suffix}")

    def parse_bytes(self, data: bytes, import_to_db: bool = True) -> Dict[str, Any]:
        """
        Parse TASKDATA.XML from bytes.

        Args:
            data: XML content as bytes
            import_to_db: If True and db is set, import to database

        Returns:
            Dictionary with parsed entity counts
        """
        from io import BytesIO
        return self._parse_xml(BytesIO(data), import_to_db)

    def _parse_zip(self, zip_path: str, import_to_db: bool) -> Dict[str, Any]:
        """Parse TASKDATA.ZIP archive"""
        with zipfile.ZipFile(zip_path, "r") as zf:
            # Find TASKDATA.XML (case-insensitive)
            taskdata_name = None
            for name in zf.namelist():
                if name.upper().endswith("TASKDATA.XML"):
                    taskdata_name = name
                    break

            if not taskdata_name:
                raise ValueError("No TASKDATA.XML found in archive")

            # Extract to temp directory for external file references
            import tempfile
            with tempfile.TemporaryDirectory() as tmpdir:
                zf.extractall(tmpdir)
                self._base_dir = os.path.dirname(os.path.join(tmpdir, taskdata_name))

                with open(os.path.join(tmpdir, taskdata_name), "rb") as f:
                    return self._parse_xml(f, import_to_db)

    def _parse_xml(self, file: BinaryIO, import_to_db: bool) -> Dict[str, Any]:
        """Parse TASKDATA.XML content"""
        tree = ET.parse(file)
        root = tree.getroot()

        # Parse all entity types
        self._parse_customers(root)
        self._parse_farms(root)
        self._parse_partfields(root)
        self._parse_devices(root)
        self._parse_products(root)
        self._parse_guidance_groups(root)
        self._parse_tasks(root)

        # Import to database if requested
        if import_to_db and self.db:
            self._import_to_database()

        return {
            "customers": len(self.customers),
            "farms": len(self.farms),
            "partfields": len(self.partfields),
            "tasks": len(self.tasks),
            "devices": len(self.devices),
            "products": len(self.products),
            "guidance_lines": len(self.guidance_lines),
            "headlands": len(self.headlands),
        }

    # =========================================================================
    # Entity Parsing
    # =========================================================================

    def _parse_customers(self, root: ET.Element):
        """Parse CTR (Customer) elements"""
        for elem in root.findall(".//CTR"):
            ctr_id = elem.get("A")  # Customer ID
            name = elem.get("B", "Unknown")  # Customer name

            if ctr_id:
                self.customers[ctr_id] = ISOCustomer(
                    id=ctr_id,
                    name=name
                )

    def _parse_farms(self, root: ET.Element):
        """Parse FRM (Farm) elements"""
        for elem in root.findall(".//FRM"):
            frm_id = elem.get("A")  # Farm ID
            name = elem.get("B", "Unknown")  # Designator
            street = elem.get("C")  # Street
            city = elem.get("E")  # City
            customer_id = elem.get("I")  # Customer ID ref

            if frm_id:
                # In ISOXML, FRM has Customer ref, but our model has farmer_id
                # We'll create a mapping or use customer_id as farmer_id placeholder
                address = None
                if street or city:
                    address = f"{street or ''} {city or ''}".strip()

                self.farms[frm_id] = ISOFarm(
                    id=frm_id,
                    farmer_id=customer_id or "default",
                    name=name,
                    address=address
                )

    def _parse_partfields(self, root: ET.Element):
        """Parse PFD (Partfield) elements"""
        for elem in root.findall(".//PFD"):
            pfd_id = elem.get("A")  # Partfield ID
            name = elem.get("C", "Unknown")  # Designator
            area = elem.get("D")  # Area in m²
            farm_id = elem.get("F")  # Farm ID ref
            crop_type = elem.get("G")  # Crop type

            if pfd_id:
                # Parse boundary polygon
                boundary = self._parse_polygon(elem)

                area_m2 = None
                if area:
                    try:
                        area_m2 = float(area)
                    except ValueError:
                        pass

                self.partfields[pfd_id] = ISOPartfield(
                    id=pfd_id,
                    farm_id=farm_id or "default",
                    name=name,
                    area_m2=area_m2,
                    crop_type=crop_type,
                    boundary=boundary
                )

    def _parse_polygon(self, parent: ET.Element) -> Optional[List[BoundaryPoint]]:
        """Parse PLN (Polygon) element from parent"""
        pln = parent.find(".//PLN")
        if pln is None:
            return None

        points = []
        for lsg in pln.findall(".//LSG"):
            lsg_type = lsg.get("A")  # 1=Polygon exterior, 2=interior
            if lsg_type == "1":  # Exterior boundary
                for pnt in lsg.findall(".//PNT"):
                    lat, lon = self._parse_point(pnt)
                    if lat is not None and lon is not None:
                        points.append(BoundaryPoint(latitude=lat, longitude=lon))

        return points if points else None

    def _parse_point(self, pnt: ET.Element) -> Tuple[Optional[float], Optional[float]]:
        """Parse PNT (Point) element"""
        pnt_type = pnt.get("A")  # Point type
        lat_str = pnt.get("C")  # North (latitude in degrees)
        lon_str = pnt.get("D")  # East (longitude in degrees)

        lat = None
        lon = None

        if lat_str:
            try:
                lat = float(lat_str)
            except ValueError:
                pass

        if lon_str:
            try:
                lon = float(lon_str)
            except ValueError:
                pass

        return lat, lon

    def _parse_devices(self, root: ET.Element):
        """Parse DVC (Device) elements"""
        for elem in root.findall(".//DVC"):
            dvc_id = elem.get("A")  # Device ID
            name = elem.get("B", "Unknown")  # Designator
            serial = elem.get("D")  # Serial number

            if dvc_id:
                # Parse device properties
                config = self._parse_device_config(elem)

                # Determine device type from elements
                device_type = DeviceType.OTHER
                det_elem = elem.find(".//DET")
                if det_elem is not None:
                    det_type = det_elem.get("C")
                    if det_type:
                        device_type = self._map_device_type(int(det_type))

                self.devices[dvc_id] = ISODevice(
                    id=dvc_id,
                    name=name,
                    device_type=device_type,
                    config=config
                )

    def _parse_device_config(self, dvc: ET.Element) -> Optional[DeviceConfig]:
        """Parse device configuration from DVC element"""
        config = DeviceConfig()

        # Parse device properties (DPT elements)
        for dpt in dvc.findall(".//DPT"):
            ddi = dpt.get("B")  # DDI (Data Dictionary Identifier)
            value = dpt.get("C")  # Value

            if ddi and value:
                try:
                    val = int(value)
                    # Common DDIs for vehicle parameters
                    if ddi == "0046":  # Working width
                        config.work_width = val / 1000.0  # mm to m
                    elif ddi == "0047":  # Wheelbase
                        config.wheelbase = val / 1000.0  # mm to m
                except ValueError:
                    pass

        return config if config.wheelbase or config.work_width else None

    def _map_device_type(self, det_type: int) -> DeviceType:
        """Map ISOXML device element type to DeviceType"""
        # ISOXML DET types (simplified mapping)
        mapping = {
            1: DeviceType.TRACTOR,
            2: DeviceType.TRACTOR,  # Harvester
            3: DeviceType.SPRAYER,
            4: DeviceType.PLANTER,
            5: DeviceType.SEEDER,
            6: DeviceType.TILLAGE,
        }
        return mapping.get(det_type, DeviceType.OTHER)

    def _parse_products(self, root: ET.Element):
        """Parse PDT (Product) elements"""
        for elem in root.findall(".//PDT"):
            pdt_id = elem.get("A")  # Product ID
            name = elem.get("B", "Unknown")  # Designator
            group = elem.get("C")  # Product group

            if pdt_id:
                # Map product group to type
                product_type = self._map_product_type(group)

                self.products[pdt_id] = ISOProduct(
                    id=pdt_id,
                    name=name,
                    product_type=product_type
                )

    def _map_product_type(self, group: Optional[str]) -> ProductType:
        """Map ISOXML product group to ProductType"""
        if not group:
            return ProductType.OTHER

        group_lower = group.lower()
        if "seed" in group_lower:
            return ProductType.SEED
        elif "fertil" in group_lower:
            return ProductType.FERTILIZER
        elif "herb" in group_lower:
            return ProductType.HERBICIDE
        elif "pest" in group_lower:
            return ProductType.PESTICIDE
        elif "fung" in group_lower:
            return ProductType.FUNGICIDE
        else:
            return ProductType.OTHER

    def _parse_guidance_groups(self, root: ET.Element):
        """Parse GGP (Guidance Group) and related elements"""
        for ggp in root.findall(".//GGP"):
            partfield_id = ggp.get("B")  # Partfield ID ref

            # Parse guidance patterns within group
            for gpn in ggp.findall(".//GPN"):
                self._parse_guidance_pattern(gpn, partfield_id)

    def _parse_guidance_pattern(self, gpn: ET.Element, partfield_id: Optional[str]):
        """Parse GPN (Guidance Pattern) element"""
        gpn_id = gpn.get("A")
        pattern_type = gpn.get("B")  # 1=AB, 2=A+, 3=Curve, etc.
        heading = gpn.get("H")  # Heading in degrees
        spacing = gpn.get("D")  # Spacing in mm

        if not gpn_id:
            return

        # Parse boundary/centerline
        points = []
        lsg = gpn.find(".//LSG")
        if lsg is not None:
            for pnt in lsg.findall(".//PNT"):
                lat, lon = self._parse_point(pnt)
                if lat is not None and lon is not None:
                    points.append(GuidancePoint(latitude=lat, longitude=lon))

        if not points:
            return

        # Determine line type
        line_type = GuidanceLineType.STRAIGHT_AB
        if pattern_type == "3":
            line_type = GuidanceLineType.CURVED_AB

        # Parse spacing
        spacing_m = 6.0  # Default
        if spacing:
            try:
                spacing_m = float(spacing) / 1000.0  # mm to m
            except ValueError:
                pass

        # Parse heading
        heading_deg = None
        if heading:
            try:
                heading_deg = float(heading)
            except ValueError:
                pass

        self.guidance_lines[gpn_id] = ISOGuidanceLine(
            id=gpn_id,
            partfield_id=partfield_id or "default",
            type=line_type,
            points=points,
            spacing_m=spacing_m,
            heading_deg=heading_deg
        )

    def _parse_tasks(self, root: ET.Element):
        """Parse TSK (Task) elements"""
        for elem in root.findall(".//TSK"):
            tsk_id = elem.get("A")  # Task ID
            name = elem.get("B", "Unknown")  # Designator
            status = elem.get("G")  # Status (1=planned, 2=running, 3=paused, 4=completed)
            partfield_ref = elem.get("E")  # Partfield ID ref
            device_ref = elem.get("H")  # Device ID ref (from OTP)

            if tsk_id:
                # Map ISOXML status to TaskStatus
                task_status = self._map_task_status(status)

                # Determine task type from treatment zones or defaults
                task_type = TaskType.OTHER

                # Check for OTP (OperationTechniquePractice) references
                otp = elem.find(".//OTP")
                if otp is not None:
                    # OTP can give hints about task type
                    pass

                self.tasks[tsk_id] = ISOTask(
                    id=tsk_id,
                    partfield_id=partfield_ref or "default",
                    name=name,
                    task_type=task_type,
                    status=task_status,
                    device_id=device_ref
                )

    def _map_task_status(self, status: Optional[str]) -> TaskStatus:
        """Map ISOXML task status to TaskStatus"""
        if not status:
            return TaskStatus.PENDING

        mapping = {
            "1": TaskStatus.PENDING,
            "2": TaskStatus.IN_PROGRESS,
            "3": TaskStatus.PAUSED,
            "4": TaskStatus.COMPLETED,
            "5": TaskStatus.CANCELLED,
        }
        return mapping.get(status, TaskStatus.PENDING)

    # =========================================================================
    # Database Import
    # =========================================================================

    def _import_to_database(self):
        """Import parsed data to database"""
        if not self.db:
            return

        # Create a default customer/farmer if needed
        default_customer = self.db.create_customer("Default Customer")
        default_farmer = None
        if default_customer:
            default_farmer = self.db.create_farmer(
                default_customer.id, "Default", first_name="Imported"
            )

        # Import customers
        for ctr_id, customer in self.customers.items():
            new_customer = self.db.create_customer(customer.name)
            if new_customer:
                self._id_map[ctr_id] = new_customer.id

        # Import farms (need farmer, use default)
        for frm_id, farm in self.farms.items():
            farmer_id = self._id_map.get(farm.farmer_id)
            if not farmer_id and default_farmer:
                farmer_id = default_farmer.id

            if farmer_id:
                new_farm = self.db.create_farm(farmer_id, farm.name, farm.address, farm.notes)
                if new_farm:
                    self._id_map[frm_id] = new_farm.id

        # Import partfields
        for pfd_id, pf in self.partfields.items():
            farm_id = self._id_map.get(pf.farm_id)
            if not farm_id:
                # Create default farm if needed
                if default_farmer:
                    farm = self.db.create_farm(default_farmer.id, "Default Farm")
                    if farm:
                        farm_id = farm.id
                        self._id_map["default"] = farm_id

            if farm_id:
                new_pf = self.db.create_partfield(
                    farm_id, pf.name, pf.season, pf.crop_type, pf.boundary, pf.notes
                )
                if new_pf:
                    self._id_map[pfd_id] = new_pf.id

        # Import devices
        for dvc_id, device in self.devices.items():
            new_device = self.db.create_device(device.name, device.device_type, device.config)
            if new_device:
                self._id_map[dvc_id] = new_device.id

        # Import products
        for pdt_id, product in self.products.items():
            new_product = self.db.create_product(
                product.name, product.product_type, product.unit, product.notes
            )
            if new_product:
                self._id_map[pdt_id] = new_product.id

        # Import guidance lines
        for gln_id, line in self.guidance_lines.items():
            partfield_id = self._id_map.get(line.partfield_id)
            if partfield_id:
                new_line = self.db.create_guidance_line(
                    partfield_id, line.type, line.points, line.spacing_m, line.heading_deg
                )
                if new_line:
                    self._id_map[gln_id] = new_line.id

        # Import tasks
        for tsk_id, task in self.tasks.items():
            partfield_id = self._id_map.get(task.partfield_id)
            if not partfield_id:
                # Use first available partfield or skip
                partfields = self.db.get_all_partfields()
                if partfields:
                    partfield_id = partfields[0].id

            if partfield_id:
                device_id = self._id_map.get(task.device_id) if task.device_id else None
                guidance_id = self._id_map.get(task.guidance_line_id) if task.guidance_line_id else None

                new_task = self.db.create_task(
                    partfield_id, task.name, task.task_type, device_id,
                    guidance_line_id=guidance_id, notes=task.notes
                )
                if new_task:
                    self._id_map[tsk_id] = new_task.id

    def get_id_mapping(self) -> Dict[str, str]:
        """Get mapping from original ISOXML IDs to internal IDs"""
        return self._id_map.copy()


# =============================================================================
# Convenience Functions
# =============================================================================


def parse_isoxml(path: str, db: Optional[DatabaseManager] = None) -> ISOXMLParser:
    """
    Parse an ISOXML file and optionally import to database.

    Args:
        path: Path to TASKDATA.XML or TASKDATA.ZIP
        db: Optional DatabaseManager for storage

    Returns:
        ISOXMLParser instance with parsed data
    """
    parser = ISOXMLParser(db)
    parser.parse_file(path, import_to_db=db is not None)
    return parser


def parse_isoxml_bytes(data: bytes, db: Optional[DatabaseManager] = None) -> ISOXMLParser:
    """
    Parse ISOXML from bytes.

    Args:
        data: XML content as bytes
        db: Optional DatabaseManager for storage

    Returns:
        ISOXMLParser instance with parsed data
    """
    parser = ISOXMLParser(db)
    parser.parse_bytes(data, import_to_db=db is not None)
    return parser
