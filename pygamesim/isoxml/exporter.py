"""
ISOXML Exporter for TaskData.xml

Exports Python data models to ISO 11783-10 TaskData format.
Supports generating both raw XML files and TASKDATA.ZIP archives.
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom
import zipfile
import os
import io
from datetime import datetime
from typing import Optional, List, Dict, Any, Set
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
)
from .database import DatabaseManager


class ISOXMLExporter:
    """
    Exporter for ISOXML TaskData files.

    Exports data from DatabaseManager to standard ISOXML format.
    """

    def __init__(self, db: DatabaseManager):
        """
        Initialize exporter.

        Args:
            db: DatabaseManager with data to export
        """
        self.db = db

        # Track exported entities for ID consistency
        self._exported_ids: Set[str] = set()

    def export_to_file(
        self,
        output_path: str,
        farm_ids: Optional[List[str]] = None,
        partfield_ids: Optional[List[str]] = None,
        task_ids: Optional[List[str]] = None,
        include_logs: bool = False,
        as_zip: bool = True
    ) -> str:
        """
        Export data to ISOXML file.

        Args:
            output_path: Path for output file (will add extension if needed)
            farm_ids: Optional list of farm IDs to export (exports all if None)
            partfield_ids: Optional list of partfield IDs to export
            task_ids: Optional list of task IDs to export
            include_logs: If True, include task logs
            as_zip: If True, create TASKDATA.ZIP, else create TASKDATA.XML

        Returns:
            Path to the created file
        """
        # Generate XML content
        xml_content = self._generate_xml(
            farm_ids, partfield_ids, task_ids, include_logs
        )

        # Ensure proper file extension
        output_path = Path(output_path)
        if as_zip:
            if not output_path.suffix.lower() == ".zip":
                output_path = output_path.with_suffix(".zip")
            return self._write_zip(str(output_path), xml_content)
        else:
            if not output_path.suffix.lower() == ".xml":
                output_path = output_path.with_suffix(".xml")
            return self._write_xml(str(output_path), xml_content)

    def export_to_bytes(
        self,
        farm_ids: Optional[List[str]] = None,
        partfield_ids: Optional[List[str]] = None,
        task_ids: Optional[List[str]] = None,
        include_logs: bool = False,
        as_zip: bool = True
    ) -> bytes:
        """
        Export data to bytes.

        Args:
            farm_ids: Optional list of farm IDs to export
            partfield_ids: Optional list of partfield IDs to export
            task_ids: Optional list of task IDs to export
            include_logs: If True, include task logs
            as_zip: If True, return ZIP content, else return XML content

        Returns:
            Bytes content of the export
        """
        xml_content = self._generate_xml(
            farm_ids, partfield_ids, task_ids, include_logs
        )

        if as_zip:
            return self._create_zip_bytes(xml_content)
        else:
            return xml_content.encode("utf-8")

    def _generate_xml(
        self,
        farm_ids: Optional[List[str]],
        partfield_ids: Optional[List[str]],
        task_ids: Optional[List[str]],
        include_logs: bool
    ) -> str:
        """Generate TASKDATA.XML content"""
        self._exported_ids.clear()

        # Create root element
        root = ET.Element("ISO11783_TaskData")
        root.set("VersionMajor", "4")
        root.set("VersionMinor", "3")
        root.set("ManagementSoftwareManufacturer", "pygamesim")
        root.set("ManagementSoftwareVersion", "1.0")
        root.set("DataTransferOrigin", "1")  # FMIS

        # Collect data to export
        farms = self._collect_farms(farm_ids)
        partfields = self._collect_partfields(partfield_ids, farms)
        tasks = self._collect_tasks(task_ids, partfields)

        # Export customers (from farms)
        customers = self._get_related_customers(farms)
        for customer in customers:
            self._export_customer(root, customer)

        # Export farms
        for farm in farms:
            self._export_farm(root, farm)

        # Export partfields with boundaries
        for pf in partfields:
            self._export_partfield(root, pf)

        # Export guidance lines for partfields
        for pf in partfields:
            lines = self.db.get_guidance_lines_for_partfield(pf.id)
            headlands = self.db.get_headlands_for_partfield(pf.id)

            if lines or headlands:
                self._export_guidance_group(root, pf.id, lines, headlands)

        # Export devices used in tasks
        devices = self._get_related_devices(tasks)
        for device in devices:
            self._export_device(root, device)

        # Export products used in tasks
        products = self._get_related_products(tasks)
        for product in products:
            self._export_product(root, product)

        # Export tasks
        for task in tasks:
            self._export_task(root, task, include_logs)

        # Pretty print XML
        return self._prettify_xml(root)

    def _collect_farms(self, farm_ids: Optional[List[str]]) -> List[ISOFarm]:
        """Collect farms to export"""
        if farm_ids:
            return [f for f in [self.db.get_farm(fid) for fid in farm_ids] if f]
        return self.db.get_all_farms()

    def _collect_partfields(
        self,
        partfield_ids: Optional[List[str]],
        farms: List[ISOFarm]
    ) -> List[ISOPartfield]:
        """Collect partfields to export"""
        if partfield_ids:
            return [pf for pf in [self.db.get_partfield(pid) for pid in partfield_ids] if pf]

        # Get all partfields for selected farms
        partfields = []
        for farm in farms:
            partfields.extend(self.db.get_partfields_for_farm(farm.id))
        return partfields

    def _collect_tasks(
        self,
        task_ids: Optional[List[str]],
        partfields: List[ISOPartfield]
    ) -> List[ISOTask]:
        """Collect tasks to export"""
        if task_ids:
            return [t for t in [self.db.get_task(tid) for tid in task_ids] if t]

        # Get all tasks for selected partfields
        tasks = []
        for pf in partfields:
            tasks.extend(self.db.get_tasks_for_partfield(pf.id))
        return tasks

    def _get_related_customers(self, farms: List[ISOFarm]) -> List[ISOCustomer]:
        """Get customers related to farms (via farmers)"""
        # In our model, farms -> farmers -> customers
        # For simplicity, return all customers
        return self.db.get_all_customers()

    def _get_related_devices(self, tasks: List[ISOTask]) -> List[ISODevice]:
        """Get devices used in tasks"""
        device_ids = {t.device_id for t in tasks if t.device_id}
        return [d for d in [self.db.get_device(did) for did in device_ids] if d]

    def _get_related_products(self, tasks: List[ISOTask]) -> List[ISOProduct]:
        """Get products used in tasks"""
        product_ids = {t.product_id for t in tasks if t.product_id}
        return [p for p in [self.db.get_product(pid) for pid in product_ids] if p]

    # =========================================================================
    # Entity Export
    # =========================================================================

    def _export_customer(self, root: ET.Element, customer: ISOCustomer):
        """Export customer as CTR element"""
        if customer.id in self._exported_ids:
            return

        ctr = ET.SubElement(root, "CTR")
        ctr.set("A", customer.id)  # Customer ID
        ctr.set("B", customer.name)  # Designator

        self._exported_ids.add(customer.id)

    def _export_farm(self, root: ET.Element, farm: ISOFarm):
        """Export farm as FRM element"""
        if farm.id in self._exported_ids:
            return

        frm = ET.SubElement(root, "FRM")
        frm.set("A", farm.id)  # Farm ID
        frm.set("B", farm.name)  # Designator

        if farm.address:
            # Split address into street/city if possible
            frm.set("C", farm.address)  # Street

        # Customer ID reference (use farmer's customer if available)
        # For now, reference first customer
        customers = self.db.get_all_customers()
        if customers:
            frm.set("I", customers[0].id)

        self._exported_ids.add(farm.id)

    def _export_partfield(self, root: ET.Element, pf: ISOPartfield):
        """Export partfield as PFD element with polygon"""
        if pf.id in self._exported_ids:
            return

        pfd = ET.SubElement(root, "PFD")
        pfd.set("A", pf.id)  # Partfield ID
        pfd.set("C", pf.name)  # Designator

        if pf.area_m2:
            pfd.set("D", str(int(pf.area_m2)))  # Area in m²

        pfd.set("F", pf.farm_id)  # Farm ID reference

        if pf.crop_type:
            pfd.set("G", pf.crop_type)  # Crop type

        # Export boundary polygon
        if pf.boundary and len(pf.boundary) >= 3:
            self._export_polygon(pfd, pf.boundary, polygon_type="1")  # 1=Partfield boundary

        self._exported_ids.add(pf.id)

    def _export_polygon(
        self,
        parent: ET.Element,
        points: List[BoundaryPoint],
        polygon_type: str = "1"
    ):
        """Export boundary as PLN element"""
        pln = ET.SubElement(parent, "PLN")
        pln.set("A", polygon_type)  # Polygon type
        pln.set("B", "")  # Designator (optional)

        # LineString for exterior boundary
        lsg = ET.SubElement(pln, "LSG")
        lsg.set("A", "1")  # 1=Polygon exterior

        for point in points:
            pnt = ET.SubElement(lsg, "PNT")
            pnt.set("A", "2")  # Point type (2=Other)
            pnt.set("C", f"{point.latitude:.9f}")  # North (latitude)
            pnt.set("D", f"{point.longitude:.9f}")  # East (longitude)

    def _export_guidance_group(
        self,
        root: ET.Element,
        partfield_id: str,
        lines: List[ISOGuidanceLine],
        headlands: List[ISOHeadland]
    ):
        """Export guidance data as GGP element"""
        ggp_id = f"GGP{partfield_id[-4:]}"
        if ggp_id in self._exported_ids:
            return

        ggp = ET.SubElement(root, "GGP")
        ggp.set("A", ggp_id)  # Guidance group ID
        ggp.set("B", partfield_id)  # Partfield ID reference

        # Export guidance lines as patterns
        for line in lines:
            self._export_guidance_pattern(ggp, line)

        # Export headlands (as polygon boundaries within guidance group)
        for headland in headlands:
            self._export_headland_boundary(ggp, headland)

        self._exported_ids.add(ggp_id)

    def _export_guidance_pattern(self, ggp: ET.Element, line: ISOGuidanceLine):
        """Export guidance line as GPN element"""
        gpn = ET.SubElement(ggp, "GPN")
        gpn.set("A", line.id)  # Pattern ID

        # Pattern type
        if line.type == GuidanceLineType.STRAIGHT_AB:
            gpn.set("B", "1")  # AB line
        else:
            gpn.set("B", "3")  # Curve

        # Spacing in mm
        gpn.set("D", str(int(line.spacing_m * 1000)))

        # Heading
        if line.heading_deg is not None:
            gpn.set("H", f"{line.heading_deg:.2f}")

        # Export centerline points
        if line.points:
            lsg = ET.SubElement(gpn, "LSG")
            lsg.set("A", "4")  # 4=GuidanceLine

            for point in line.points:
                pnt = ET.SubElement(lsg, "PNT")
                pnt.set("A", "2")  # Point type
                pnt.set("C", f"{point.latitude:.9f}")
                pnt.set("D", f"{point.longitude:.9f}")

    def _export_headland_boundary(self, ggp: ET.Element, headland: ISOHeadland):
        """Export headland as boundary polygon within guidance group"""
        # Headlands are exported as boundary polygons with offset metadata
        pln = ET.SubElement(ggp, "PLN")
        pln.set("A", "3")  # 3=Headland

        lsg = ET.SubElement(pln, "LSG")
        lsg.set("A", "1")  # Exterior

        for point in headland.boundary:
            pnt = ET.SubElement(lsg, "PNT")
            pnt.set("A", "2")
            pnt.set("C", f"{point.latitude:.9f}")
            pnt.set("D", f"{point.longitude:.9f}")

    def _export_device(self, root: ET.Element, device: ISODevice):
        """Export device as DVC element"""
        if device.id in self._exported_ids:
            return

        dvc = ET.SubElement(root, "DVC")
        dvc.set("A", device.id)  # Device ID
        dvc.set("B", device.name)  # Designator
        dvc.set("F", "FF")  # Client name (placeholder)

        # Device element type
        det = ET.SubElement(dvc, "DET")
        det.set("A", f"DET{device.id[-4:]}")  # Element ID
        det.set("B", "1")  # Element number

        # Map device type to ISOXML type
        det_type = self._map_device_type_to_isoxml(device.device_type)
        det.set("C", str(det_type))

        # Export device properties
        if device.config:
            if device.config.work_width:
                self._export_device_property(dvc, "0046", int(device.config.work_width * 1000))
            if device.config.wheelbase:
                self._export_device_property(dvc, "0047", int(device.config.wheelbase * 1000))

        self._exported_ids.add(device.id)

    def _export_device_property(self, dvc: ET.Element, ddi: str, value: int):
        """Export device property as DPT element"""
        dpt = ET.SubElement(dvc, "DPT")
        dpt.set("A", f"DPT{ddi}")  # Property ID
        dpt.set("B", ddi)  # DDI
        dpt.set("C", str(value))  # Value

    def _map_device_type_to_isoxml(self, device_type: DeviceType) -> int:
        """Map DeviceType to ISOXML device element type"""
        mapping = {
            DeviceType.TRACTOR: 1,
            DeviceType.COMBINE: 2,
            DeviceType.SPRAYER: 3,
            DeviceType.PLANTER: 4,
            DeviceType.SEEDER: 5,
            DeviceType.TILLAGE: 6,
            DeviceType.OTHER: 7,
        }
        return mapping.get(device_type, 7)

    def _export_product(self, root: ET.Element, product: ISOProduct):
        """Export product as PDT element"""
        if product.id in self._exported_ids:
            return

        pdt = ET.SubElement(root, "PDT")
        pdt.set("A", product.id)  # Product ID
        pdt.set("B", product.name)  # Designator
        pdt.set("C", product.product_type.value)  # Product group

        if product.unit:
            pdt.set("D", product.unit)

        self._exported_ids.add(product.id)

    def _export_task(self, root: ET.Element, task: ISOTask, include_logs: bool):
        """Export task as TSK element"""
        if task.id in self._exported_ids:
            return

        tsk = ET.SubElement(root, "TSK")
        tsk.set("A", task.id)  # Task ID
        tsk.set("B", task.name)  # Designator
        tsk.set("E", task.partfield_id)  # Partfield ID reference

        # Task status
        status_map = {
            TaskStatus.PENDING: "1",
            TaskStatus.IN_PROGRESS: "2",
            TaskStatus.PAUSED: "3",
            TaskStatus.COMPLETED: "4",
            TaskStatus.CANCELLED: "5",
        }
        tsk.set("G", status_map.get(task.status, "1"))

        # Device reference via OTP
        if task.device_id:
            otp = ET.SubElement(tsk, "OTP")
            otp.set("A", task.device_id)
            otp.set("B", "0")  # Technique index

        # Guidance line reference via GAN
        if task.guidance_line_id:
            gan = ET.SubElement(tsk, "GAN")
            gan.set("A", f"GGP{task.partfield_id[-4:]}")  # Guidance group ref
            gan.set("B", task.guidance_line_id)  # Pattern ref

        # Time log reference
        if include_logs:
            logs = self.db.get_task_logs(task.id)
            if logs:
                tlg = ET.SubElement(tsk, "TLG")
                tlg.set("A", f"TLG{task.id[-4:]}")  # Time log filename
                tlg.set("B", "1")  # Time log type (1=binary)

        self._exported_ids.add(task.id)

    # =========================================================================
    # Output
    # =========================================================================

    def _prettify_xml(self, root: ET.Element) -> str:
        """Convert element tree to pretty-printed XML string"""
        rough_string = ET.tostring(root, encoding="unicode")
        reparsed = minidom.parseString(rough_string)
        return reparsed.toprettyxml(indent="  ", encoding=None)

    def _write_xml(self, path: str, content: str) -> str:
        """Write XML content to file"""
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def _write_zip(self, path: str, xml_content: str) -> str:
        """Write XML content to ZIP archive"""
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("TASKDATA/TASKDATA.XML", xml_content.encode("utf-8"))
        return path

    def _create_zip_bytes(self, xml_content: str) -> bytes:
        """Create ZIP archive in memory"""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("TASKDATA/TASKDATA.XML", xml_content.encode("utf-8"))
        return buffer.getvalue()


# =============================================================================
# Convenience Functions
# =============================================================================


def export_isoxml(
    db: DatabaseManager,
    output_path: str,
    farm_ids: Optional[List[str]] = None,
    as_zip: bool = True
) -> str:
    """
    Export database to ISOXML file.

    Args:
        db: DatabaseManager with data to export
        output_path: Path for output file
        farm_ids: Optional list of farm IDs (exports all if None)
        as_zip: If True, create ZIP archive

    Returns:
        Path to created file
    """
    exporter = ISOXMLExporter(db)
    return exporter.export_to_file(output_path, farm_ids=farm_ids, as_zip=as_zip)


def export_isoxml_bytes(
    db: DatabaseManager,
    farm_ids: Optional[List[str]] = None,
    as_zip: bool = True
) -> bytes:
    """
    Export database to ISOXML bytes.

    Args:
        db: DatabaseManager with data to export
        farm_ids: Optional list of farm IDs (exports all if None)
        as_zip: If True, create ZIP content

    Returns:
        Bytes content of the export
    """
    exporter = ISOXMLExporter(db)
    return exporter.export_to_bytes(farm_ids=farm_ids, as_zip=as_zip)
