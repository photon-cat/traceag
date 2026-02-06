"""
SQLite Database Manager for ISOXML agricultural data

Thread-safe database manager with CRUD operations for all ISOXML entities.
Schema is aligned with iOS DatabaseManager for cross-platform compatibility.
"""

import sqlite3
import json
import os
import threading
from datetime import datetime
from typing import Optional, List, Dict, Any, Set, Tuple
from contextlib import contextmanager
import time
import random

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
    TaskLogEntry,
    CoverageCell,
)


class DatabaseManager:
    """Thread-safe SQLite database manager for ISOXML agricultural data"""

    _instance: Optional["DatabaseManager"] = None
    _lock = threading.Lock()

    def __init__(self, db_path: Optional[str] = None):
        """
        Initialize database manager.

        Args:
            db_path: Path to SQLite database file. If None, uses default in user data dir.
        """
        if db_path is None:
            # Use default path in user data directory
            data_dir = os.path.join(os.path.expanduser("~"), ".pygamesim")
            os.makedirs(data_dir, exist_ok=True)
            db_path = os.path.join(data_dir, "isoxml_data.sqlite")

        self.db_path = db_path
        self._local = threading.local()
        self._create_tables()

    @classmethod
    def shared(cls, db_path: Optional[str] = None) -> "DatabaseManager":
        """Get or create singleton instance"""
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls(db_path)
            return cls._instance

    @contextmanager
    def _get_connection(self):
        """Get thread-local database connection"""
        if not hasattr(self._local, "connection") or self._local.connection is None:
            self._local.connection = sqlite3.connect(
                self.db_path,
                check_same_thread=False,
                detect_types=sqlite3.PARSE_DECLTYPES | sqlite3.PARSE_COLNAMES
            )
            self._local.connection.row_factory = sqlite3.Row
            self._local.connection.execute("PRAGMA foreign_keys = ON")

        try:
            yield self._local.connection
        except Exception:
            self._local.connection.rollback()
            raise

    def _create_tables(self):
        """Create all database tables"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # IdTable for entity ID resolution
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS id_table (
                    id TEXT PRIMARY KEY,
                    entity_type TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # ISOCustomer - internal account identifier
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS customers (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # ISOFarmer
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS farmers (
                    id TEXT PRIMARY KEY,
                    customer_id TEXT NOT NULL,
                    first_name TEXT,
                    last_name TEXT NOT NULL,
                    email TEXT,
                    phone TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
                )
            """)

            # ISOFarm
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS farms (
                    id TEXT PRIMARY KEY,
                    farmer_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    address TEXT,
                    notes TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (farmer_id) REFERENCES farmers(id) ON DELETE CASCADE
                )
            """)

            # ISOPartfield (Field)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS partfields (
                    id TEXT PRIMARY KEY,
                    farm_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    area_m2 REAL,
                    season TEXT,
                    crop_type TEXT,
                    notes TEXT,
                    boundary_json TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE
                )
            """)

            # ISOTask
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id TEXT PRIMARY KEY,
                    partfield_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    task_type TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    device_id TEXT,
                    product_id TEXT,
                    guidance_line_id TEXT,
                    headland_id TEXT,
                    notes TEXT,
                    started_at TEXT,
                    completed_at TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (partfield_id) REFERENCES partfields(id) ON DELETE CASCADE
                )
            """)

            # Guidance lines (AB / curved)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS guidance_lines (
                    id TEXT PRIMARY KEY,
                    partfield_id TEXT NOT NULL,
                    type TEXT NOT NULL,
                    points_json TEXT NOT NULL,
                    spacing_m REAL,
                    heading_deg REAL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (partfield_id) REFERENCES partfields(id) ON DELETE CASCADE
                )
            """)

            # Headlands
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS headlands (
                    id TEXT PRIMARY KEY,
                    partfield_id TEXT NOT NULL,
                    boundary_json TEXT NOT NULL,
                    offset_m REAL,
                    direction TEXT DEFAULT 'inward',
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (partfield_id) REFERENCES partfields(id) ON DELETE CASCADE
                )
            """)

            # Task logs for operation data
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS task_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    task_id TEXT NOT NULL,
                    timestamp TEXT NOT NULL,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    heading REAL,
                    speed REAL,
                    data_json TEXT,
                    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
                )
            """)

            # Coverage data for fields
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS coverage_data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    task_id TEXT NOT NULL,
                    cell_row INTEGER NOT NULL,
                    cell_col INTEGER NOT NULL,
                    timestamp TEXT NOT NULL,
                    UNIQUE(task_id, cell_row, cell_col),
                    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
                )
            """)

            # Devices (implements, machines)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS devices (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    device_type TEXT NOT NULL,
                    config_json TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Products (seeds, fertilizers, etc.)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    product_type TEXT NOT NULL,
                    unit TEXT,
                    notes TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Create indexes
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_guidance_lines_partfield ON guidance_lines(partfield_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_headlands_partfield ON headlands(partfield_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_tasklog_task_timestamp ON task_logs(task_id, timestamp)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_tasks_partfield ON tasks(partfield_id)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_partfields_farm ON partfields(farm_id)")

            conn.commit()

    # =========================================================================
    # ID Generation
    # =========================================================================

    def generate_id(self, prefix: str) -> str:
        """Generate a unique ID with the given ISOXML prefix"""
        timestamp = int(time.time() * 1000) % 100000
        rand = random.randint(1000, 9999)
        return f"{prefix}{timestamp}{rand}"

    # =========================================================================
    # IdTable Operations
    # =========================================================================

    def register_entity(self, entity_id: str, entity_type: EntityType):
        """Register an entity in the IdTable"""
        with self._get_connection() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO id_table (id, entity_type) VALUES (?, ?)",
                (entity_id, entity_type.value)
            )
            conn.commit()

    def resolve_entity_type(self, entity_id: str) -> Optional[EntityType]:
        """Resolve entity type from IdTable"""
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT entity_type FROM id_table WHERE id = ?",
                (entity_id,)
            ).fetchone()
            if row:
                return EntityType(row["entity_type"])
            return None

    # =========================================================================
    # Customer Operations
    # =========================================================================

    def create_customer(self, name: str) -> Optional[ISOCustomer]:
        """Create a new customer"""
        customer_id = self.generate_id("CTR")
        with self._get_connection() as conn:
            conn.execute(
                "INSERT INTO customers (id, name) VALUES (?, ?)",
                (customer_id, name)
            )
            conn.commit()
            self.register_entity(customer_id, EntityType.CUSTOMER)
            return ISOCustomer(id=customer_id, name=name)

    def get_customer(self, customer_id: str) -> Optional[ISOCustomer]:
        """Get a customer by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT id, name, created_at, updated_at FROM customers WHERE id = ?",
                (customer_id,)
            ).fetchone()
            if row:
                return ISOCustomer(
                    id=row["id"],
                    name=row["name"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_all_customers(self) -> List[ISOCustomer]:
        """Get all customers"""
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT id, name, created_at, updated_at FROM customers ORDER BY name"
            ).fetchall()
            return [
                ISOCustomer(
                    id=row["id"],
                    name=row["name"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    # =========================================================================
    # Farmer Operations
    # =========================================================================

    def create_farmer(
        self,
        customer_id: str,
        last_name: str,
        first_name: Optional[str] = None,
        email: Optional[str] = None,
        phone: Optional[str] = None
    ) -> Optional[ISOFarmer]:
        """Create a new farmer"""
        farmer_id = self.generate_id("FRM")
        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO farmers (id, customer_id, first_name, last_name, email, phone)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (farmer_id, customer_id, first_name, last_name, email, phone)
            )
            conn.commit()
            self.register_entity(farmer_id, EntityType.FARMER)
            return ISOFarmer(
                id=farmer_id,
                customer_id=customer_id,
                first_name=first_name,
                last_name=last_name,
                email=email,
                phone=phone
            )

    def get_farmers_for_customer(self, customer_id: str) -> List[ISOFarmer]:
        """Get all farmers for a customer"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, customer_id, first_name, last_name, email, phone, created_at, updated_at
                   FROM farmers WHERE customer_id = ? ORDER BY last_name""",
                (customer_id,)
            ).fetchall()
            return [
                ISOFarmer(
                    id=row["id"],
                    customer_id=row["customer_id"],
                    first_name=row["first_name"],
                    last_name=row["last_name"],
                    email=row["email"],
                    phone=row["phone"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    # =========================================================================
    # Farm Operations
    # =========================================================================

    def create_farm(
        self,
        farmer_id: str,
        name: str,
        address: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Optional[ISOFarm]:
        """Create a new farm"""
        farm_id = self.generate_id("FAR")
        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO farms (id, farmer_id, name, address, notes)
                   VALUES (?, ?, ?, ?, ?)""",
                (farm_id, farmer_id, name, address, notes)
            )
            conn.commit()
            self.register_entity(farm_id, EntityType.FARM)
            return ISOFarm(
                id=farm_id,
                farmer_id=farmer_id,
                name=name,
                address=address,
                notes=notes
            )

    def get_farm(self, farm_id: str) -> Optional[ISOFarm]:
        """Get a farm by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, farmer_id, name, address, notes, created_at, updated_at
                   FROM farms WHERE id = ?""",
                (farm_id,)
            ).fetchone()
            if row:
                return ISOFarm(
                    id=row["id"],
                    farmer_id=row["farmer_id"],
                    name=row["name"],
                    address=row["address"],
                    notes=row["notes"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_farms_for_farmer(self, farmer_id: str) -> List[ISOFarm]:
        """Get all farms for a farmer"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, farmer_id, name, address, notes, created_at, updated_at
                   FROM farms WHERE farmer_id = ? ORDER BY name""",
                (farmer_id,)
            ).fetchall()
            return [
                ISOFarm(
                    id=row["id"],
                    farmer_id=row["farmer_id"],
                    name=row["name"],
                    address=row["address"],
                    notes=row["notes"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    def get_all_farms(self) -> List[ISOFarm]:
        """Get all farms"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, farmer_id, name, address, notes, created_at, updated_at
                   FROM farms ORDER BY name"""
            ).fetchall()
            return [
                ISOFarm(
                    id=row["id"],
                    farmer_id=row["farmer_id"],
                    name=row["name"],
                    address=row["address"],
                    notes=row["notes"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    # =========================================================================
    # Partfield (Field) Operations
    # =========================================================================

    def create_partfield(
        self,
        farm_id: str,
        name: str,
        season: Optional[str] = None,
        crop_type: Optional[str] = None,
        boundary: Optional[List[BoundaryPoint]] = None,
        notes: Optional[str] = None
    ) -> Optional[ISOPartfield]:
        """Create a new partfield"""
        partfield_id = self.generate_id("PFD")
        boundary_json = None
        if boundary:
            boundary_json = json.dumps([p.to_dict() for p in boundary])

        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO partfields (id, farm_id, name, season, crop_type, notes, boundary_json)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (partfield_id, farm_id, name, season, crop_type, notes, boundary_json)
            )
            conn.commit()
            self.register_entity(partfield_id, EntityType.PARTFIELD)
            pf = ISOPartfield(
                id=partfield_id,
                farm_id=farm_id,
                name=name,
                season=season,
                crop_type=crop_type,
                notes=notes,
                boundary=boundary
            )
            if boundary:
                pf.calculate_area()
                self.update_partfield_area(partfield_id, pf.area_m2)
            return pf

    def get_partfield(self, partfield_id: str) -> Optional[ISOPartfield]:
        """Get a partfield by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, farm_id, name, area_m2, season, crop_type, notes, boundary_json,
                          created_at, updated_at
                   FROM partfields WHERE id = ?""",
                (partfield_id,)
            ).fetchone()
            if row:
                boundary = None
                if row["boundary_json"]:
                    boundary = [BoundaryPoint.from_dict(p) for p in json.loads(row["boundary_json"])]
                return ISOPartfield(
                    id=row["id"],
                    farm_id=row["farm_id"],
                    name=row["name"],
                    area_m2=row["area_m2"],
                    season=row["season"],
                    crop_type=row["crop_type"],
                    notes=row["notes"],
                    boundary=boundary,
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_partfields_for_farm(self, farm_id: str) -> List[ISOPartfield]:
        """Get all partfields for a farm"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, farm_id, name, area_m2, season, crop_type, notes, boundary_json,
                          created_at, updated_at
                   FROM partfields WHERE farm_id = ? ORDER BY name""",
                (farm_id,)
            ).fetchall()
            result = []
            for row in rows:
                boundary = None
                if row["boundary_json"]:
                    boundary = [BoundaryPoint.from_dict(p) for p in json.loads(row["boundary_json"])]
                result.append(ISOPartfield(
                    id=row["id"],
                    farm_id=row["farm_id"],
                    name=row["name"],
                    area_m2=row["area_m2"],
                    season=row["season"],
                    crop_type=row["crop_type"],
                    notes=row["notes"],
                    boundary=boundary,
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                ))
            return result

    def get_all_partfields(self) -> List[ISOPartfield]:
        """Get all partfields"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, farm_id, name, area_m2, season, crop_type, notes, boundary_json,
                          created_at, updated_at
                   FROM partfields ORDER BY name"""
            ).fetchall()
            result = []
            for row in rows:
                boundary = None
                if row["boundary_json"]:
                    boundary = [BoundaryPoint.from_dict(p) for p in json.loads(row["boundary_json"])]
                result.append(ISOPartfield(
                    id=row["id"],
                    farm_id=row["farm_id"],
                    name=row["name"],
                    area_m2=row["area_m2"],
                    season=row["season"],
                    crop_type=row["crop_type"],
                    notes=row["notes"],
                    boundary=boundary,
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                ))
            return result

    def update_partfield_boundary(
        self,
        partfield_id: str,
        boundary: List[BoundaryPoint],
        area_m2: Optional[float] = None
    ):
        """Update partfield boundary"""
        boundary_json = json.dumps([p.to_dict() for p in boundary])
        with self._get_connection() as conn:
            if area_m2 is not None:
                conn.execute(
                    """UPDATE partfields SET boundary_json = ?, area_m2 = ?,
                       updated_at = CURRENT_TIMESTAMP WHERE id = ?""",
                    (boundary_json, area_m2, partfield_id)
                )
            else:
                conn.execute(
                    """UPDATE partfields SET boundary_json = ?,
                       updated_at = CURRENT_TIMESTAMP WHERE id = ?""",
                    (boundary_json, partfield_id)
                )
            conn.commit()

    def update_partfield_area(self, partfield_id: str, area_m2: float):
        """Update partfield area"""
        with self._get_connection() as conn:
            conn.execute(
                "UPDATE partfields SET area_m2 = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                (area_m2, partfield_id)
            )
            conn.commit()

    # =========================================================================
    # Task Operations
    # =========================================================================

    def create_task(
        self,
        partfield_id: str,
        name: str,
        task_type: TaskType,
        device_id: Optional[str] = None,
        product_id: Optional[str] = None,
        guidance_line_id: Optional[str] = None,
        headland_id: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Optional[ISOTask]:
        """Create a new task"""
        task_id = self.generate_id("TSK")
        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO tasks (id, partfield_id, name, task_type, device_id, product_id,
                                     guidance_line_id, headland_id, notes)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (task_id, partfield_id, name, task_type.value, device_id, product_id,
                 guidance_line_id, headland_id, notes)
            )
            conn.commit()
            self.register_entity(task_id, EntityType.TASK)
            return ISOTask(
                id=task_id,
                partfield_id=partfield_id,
                name=name,
                task_type=task_type,
                status=TaskStatus.PENDING,
                device_id=device_id,
                product_id=product_id,
                guidance_line_id=guidance_line_id,
                headland_id=headland_id,
                notes=notes
            )

    def get_task(self, task_id: str) -> Optional[ISOTask]:
        """Get a task by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, partfield_id, name, task_type, status, device_id, product_id,
                          guidance_line_id, headland_id, notes, started_at, completed_at,
                          created_at, updated_at
                   FROM tasks WHERE id = ?""",
                (task_id,)
            ).fetchone()
            if row:
                return ISOTask(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    name=row["name"],
                    task_type=TaskType(row["task_type"]),
                    status=TaskStatus(row["status"]),
                    device_id=row["device_id"],
                    product_id=row["product_id"],
                    guidance_line_id=row["guidance_line_id"],
                    headland_id=row["headland_id"],
                    notes=row["notes"],
                    started_at=_parse_datetime(row["started_at"]),
                    completed_at=_parse_datetime(row["completed_at"]),
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_tasks_for_partfield(self, partfield_id: str) -> List[ISOTask]:
        """Get all tasks for a partfield"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, partfield_id, name, task_type, status, device_id, product_id,
                          guidance_line_id, headland_id, notes, started_at, completed_at,
                          created_at, updated_at
                   FROM tasks WHERE partfield_id = ? ORDER BY created_at DESC""",
                (partfield_id,)
            ).fetchall()
            return [
                ISOTask(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    name=row["name"],
                    task_type=TaskType(row["task_type"]),
                    status=TaskStatus(row["status"]),
                    device_id=row["device_id"],
                    product_id=row["product_id"],
                    guidance_line_id=row["guidance_line_id"],
                    headland_id=row["headland_id"],
                    notes=row["notes"],
                    started_at=_parse_datetime(row["started_at"]),
                    completed_at=_parse_datetime(row["completed_at"]),
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    def get_all_tasks(self) -> List[ISOTask]:
        """Get all tasks"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, partfield_id, name, task_type, status, device_id, product_id,
                          guidance_line_id, headland_id, notes, started_at, completed_at,
                          created_at, updated_at
                   FROM tasks ORDER BY created_at DESC"""
            ).fetchall()
            return [
                ISOTask(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    name=row["name"],
                    task_type=TaskType(row["task_type"]),
                    status=TaskStatus(row["status"]),
                    device_id=row["device_id"],
                    product_id=row["product_id"],
                    guidance_line_id=row["guidance_line_id"],
                    headland_id=row["headland_id"],
                    notes=row["notes"],
                    started_at=_parse_datetime(row["started_at"]),
                    completed_at=_parse_datetime(row["completed_at"]),
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    def update_task_status(self, task_id: str, status: TaskStatus):
        """Update task status"""
        with self._get_connection() as conn:
            if status == TaskStatus.IN_PROGRESS:
                conn.execute(
                    """UPDATE tasks SET status = ?, started_at = CURRENT_TIMESTAMP,
                       updated_at = CURRENT_TIMESTAMP WHERE id = ?""",
                    (status.value, task_id)
                )
            elif status == TaskStatus.COMPLETED:
                conn.execute(
                    """UPDATE tasks SET status = ?, completed_at = CURRENT_TIMESTAMP,
                       updated_at = CURRENT_TIMESTAMP WHERE id = ?""",
                    (status.value, task_id)
                )
            else:
                conn.execute(
                    "UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                    (status.value, task_id)
                )
            conn.commit()

    def update_task_guidance_link(
        self,
        task_id: str,
        guidance_line_id: Optional[str] = None,
        headland_id: Optional[str] = None
    ):
        """Update task guidance line and headland links"""
        with self._get_connection() as conn:
            conn.execute(
                """UPDATE tasks SET guidance_line_id = ?, headland_id = ?,
                   updated_at = CURRENT_TIMESTAMP WHERE id = ?""",
                (guidance_line_id, headland_id, task_id)
            )
            conn.commit()

    # =========================================================================
    # Guidance Line Operations
    # =========================================================================

    def create_guidance_line(
        self,
        partfield_id: str,
        line_type: GuidanceLineType,
        points: List[GuidancePoint],
        spacing_m: float,
        heading_deg: Optional[float] = None
    ) -> Optional[ISOGuidanceLine]:
        """Create a new guidance line"""
        line_id = self.generate_id("GLN")
        points_json = json.dumps([p.to_dict() for p in points])

        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO guidance_lines (id, partfield_id, type, points_json, spacing_m, heading_deg)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (line_id, partfield_id, line_type.value, points_json, spacing_m, heading_deg)
            )
            conn.commit()
            self.register_entity(line_id, EntityType.GUIDANCE_LINE)
            return ISOGuidanceLine(
                id=line_id,
                partfield_id=partfield_id,
                type=line_type,
                points=points,
                spacing_m=spacing_m,
                heading_deg=heading_deg
            )

    def get_guidance_line(self, line_id: str) -> Optional[ISOGuidanceLine]:
        """Get a guidance line by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, partfield_id, type, points_json, spacing_m, heading_deg,
                          created_at, updated_at
                   FROM guidance_lines WHERE id = ?""",
                (line_id,)
            ).fetchone()
            if row:
                points = [GuidancePoint.from_dict(p) for p in json.loads(row["points_json"])]
                return ISOGuidanceLine(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    type=GuidanceLineType(row["type"]),
                    points=points,
                    spacing_m=row["spacing_m"],
                    heading_deg=row["heading_deg"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_guidance_lines_for_partfield(self, partfield_id: str) -> List[ISOGuidanceLine]:
        """Get all guidance lines for a partfield"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, partfield_id, type, points_json, spacing_m, heading_deg,
                          created_at, updated_at
                   FROM guidance_lines WHERE partfield_id = ? ORDER BY created_at DESC""",
                (partfield_id,)
            ).fetchall()
            result = []
            for row in rows:
                points = [GuidancePoint.from_dict(p) for p in json.loads(row["points_json"])]
                result.append(ISOGuidanceLine(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    type=GuidanceLineType(row["type"]),
                    points=points,
                    spacing_m=row["spacing_m"],
                    heading_deg=row["heading_deg"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                ))
            return result

    # =========================================================================
    # Headland Operations
    # =========================================================================

    def create_headland(
        self,
        partfield_id: str,
        boundary: List[BoundaryPoint],
        offset_m: float,
        direction: str = "inward"
    ) -> Optional[ISOHeadland]:
        """Create a new headland"""
        headland_id = self.generate_id("HDL")
        boundary_json = json.dumps([p.to_dict() for p in boundary])

        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO headlands (id, partfield_id, boundary_json, offset_m, direction)
                   VALUES (?, ?, ?, ?, ?)""",
                (headland_id, partfield_id, boundary_json, offset_m, direction)
            )
            conn.commit()
            self.register_entity(headland_id, EntityType.HEADLAND)
            return ISOHeadland(
                id=headland_id,
                partfield_id=partfield_id,
                boundary=boundary,
                offset_m=offset_m,
                direction=direction
            )

    def get_headland(self, headland_id: str) -> Optional[ISOHeadland]:
        """Get a headland by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, partfield_id, boundary_json, offset_m, direction,
                          created_at, updated_at
                   FROM headlands WHERE id = ?""",
                (headland_id,)
            ).fetchone()
            if row:
                boundary = [BoundaryPoint.from_dict(p) for p in json.loads(row["boundary_json"])]
                return ISOHeadland(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    boundary=boundary,
                    offset_m=row["offset_m"],
                    direction=row["direction"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_headlands_for_partfield(self, partfield_id: str) -> List[ISOHeadland]:
        """Get all headlands for a partfield"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, partfield_id, boundary_json, offset_m, direction,
                          created_at, updated_at
                   FROM headlands WHERE partfield_id = ? ORDER BY created_at DESC""",
                (partfield_id,)
            ).fetchall()
            result = []
            for row in rows:
                boundary = [BoundaryPoint.from_dict(p) for p in json.loads(row["boundary_json"])]
                result.append(ISOHeadland(
                    id=row["id"],
                    partfield_id=row["partfield_id"],
                    boundary=boundary,
                    offset_m=row["offset_m"],
                    direction=row["direction"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                ))
            return result

    # =========================================================================
    # Device Operations
    # =========================================================================

    def create_device(
        self,
        name: str,
        device_type: DeviceType,
        config: Optional[DeviceConfig] = None
    ) -> Optional[ISODevice]:
        """Create a new device"""
        device_id = self.generate_id("DVC")
        config_json = json.dumps(config.to_dict()) if config else None

        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO devices (id, name, device_type, config_json)
                   VALUES (?, ?, ?, ?)""",
                (device_id, name, device_type.value, config_json)
            )
            conn.commit()
            self.register_entity(device_id, EntityType.DEVICE)
            return ISODevice(
                id=device_id,
                name=name,
                device_type=device_type,
                config=config
            )

    def get_device(self, device_id: str) -> Optional[ISODevice]:
        """Get a device by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, name, device_type, config_json, created_at, updated_at
                   FROM devices WHERE id = ?""",
                (device_id,)
            ).fetchone()
            if row:
                config = None
                if row["config_json"]:
                    config = DeviceConfig.from_dict(json.loads(row["config_json"]))
                return ISODevice(
                    id=row["id"],
                    name=row["name"],
                    device_type=DeviceType(row["device_type"]),
                    config=config,
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_all_devices(self) -> List[ISODevice]:
        """Get all devices"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, name, device_type, config_json, created_at, updated_at
                   FROM devices ORDER BY name"""
            ).fetchall()
            result = []
            for row in rows:
                config = None
                if row["config_json"]:
                    config = DeviceConfig.from_dict(json.loads(row["config_json"]))
                result.append(ISODevice(
                    id=row["id"],
                    name=row["name"],
                    device_type=DeviceType(row["device_type"]),
                    config=config,
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                ))
            return result

    # =========================================================================
    # Product Operations
    # =========================================================================

    def create_product(
        self,
        name: str,
        product_type: ProductType,
        unit: Optional[str] = None,
        notes: Optional[str] = None
    ) -> Optional[ISOProduct]:
        """Create a new product"""
        product_id = self.generate_id("PDT")
        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO products (id, name, product_type, unit, notes)
                   VALUES (?, ?, ?, ?, ?)""",
                (product_id, name, product_type.value, unit, notes)
            )
            conn.commit()
            self.register_entity(product_id, EntityType.PRODUCT)
            return ISOProduct(
                id=product_id,
                name=name,
                product_type=product_type,
                unit=unit,
                notes=notes
            )

    def get_product(self, product_id: str) -> Optional[ISOProduct]:
        """Get a product by ID"""
        with self._get_connection() as conn:
            row = conn.execute(
                """SELECT id, name, product_type, unit, notes, created_at, updated_at
                   FROM products WHERE id = ?""",
                (product_id,)
            ).fetchone()
            if row:
                return ISOProduct(
                    id=row["id"],
                    name=row["name"],
                    product_type=ProductType(row["product_type"]),
                    unit=row["unit"],
                    notes=row["notes"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
            return None

    def get_all_products(self) -> List[ISOProduct]:
        """Get all products"""
        with self._get_connection() as conn:
            rows = conn.execute(
                """SELECT id, name, product_type, unit, notes, created_at, updated_at
                   FROM products ORDER BY name"""
            ).fetchall()
            return [
                ISOProduct(
                    id=row["id"],
                    name=row["name"],
                    product_type=ProductType(row["product_type"]),
                    unit=row["unit"],
                    notes=row["notes"],
                    created_at=_parse_datetime(row["created_at"]),
                    updated_at=_parse_datetime(row["updated_at"])
                )
                for row in rows
            ]

    # =========================================================================
    # Task Log Operations
    # =========================================================================

    def add_task_log(
        self,
        task_id: str,
        latitude: float,
        longitude: float,
        heading: Optional[float] = None,
        speed: Optional[float] = None,
        data: Optional[Dict[str, Any]] = None
    ):
        """Add a task log entry"""
        data_json = json.dumps(data) if data else None
        timestamp = datetime.now().isoformat()

        with self._get_connection() as conn:
            conn.execute(
                """INSERT INTO task_logs (task_id, timestamp, latitude, longitude, heading, speed, data_json)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (task_id, timestamp, latitude, longitude, heading, speed, data_json)
            )
            conn.commit()

    def add_task_logs_batch(self, task_id: str, logs: List[Dict[str, Any]]):
        """Add multiple task log entries in a batch"""
        with self._get_connection() as conn:
            conn.execute("BEGIN TRANSACTION")
            for log in logs:
                data_json = json.dumps(log.get("data")) if log.get("data") else None
                timestamp = log.get("timestamp", datetime.now().isoformat())
                conn.execute(
                    """INSERT INTO task_logs (task_id, timestamp, latitude, longitude, heading, speed, data_json)
                       VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (task_id, timestamp, log["latitude"], log["longitude"],
                     log.get("heading"), log.get("speed"), data_json)
                )
            conn.execute("COMMIT")

    def get_task_logs(self, task_id: str, limit: Optional[int] = None) -> List[TaskLogEntry]:
        """Get task logs for a task"""
        with self._get_connection() as conn:
            query = """SELECT id, task_id, timestamp, latitude, longitude, heading, speed, data_json
                      FROM task_logs WHERE task_id = ? ORDER BY timestamp"""
            if limit:
                query += f" LIMIT {limit}"

            rows = conn.execute(query, (task_id,)).fetchall()
            return [
                TaskLogEntry(
                    id=row["id"],
                    task_id=row["task_id"],
                    timestamp=datetime.fromisoformat(row["timestamp"]),
                    latitude=row["latitude"],
                    longitude=row["longitude"],
                    heading=row["heading"],
                    speed=row["speed"],
                    data=json.loads(row["data_json"]) if row["data_json"] else None
                )
                for row in rows
            ]

    # =========================================================================
    # Coverage Operations
    # =========================================================================

    def add_coverage_cell(self, task_id: str, row: int, col: int):
        """Add a coverage cell"""
        timestamp = datetime.now().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """INSERT OR IGNORE INTO coverage_data (task_id, cell_row, cell_col, timestamp)
                   VALUES (?, ?, ?, ?)""",
                (task_id, row, col, timestamp)
            )
            conn.commit()

    def add_coverage_cells_batch(self, task_id: str, cells: List[Tuple[int, int]]):
        """Add multiple coverage cells in a batch"""
        if not cells:
            return

        timestamp = datetime.now().isoformat()
        with self._get_connection() as conn:
            conn.execute("BEGIN TRANSACTION")
            for row, col in cells:
                conn.execute(
                    """INSERT OR IGNORE INTO coverage_data (task_id, cell_row, cell_col, timestamp)
                       VALUES (?, ?, ?, ?)""",
                    (task_id, row, col, timestamp)
                )
            conn.execute("COMMIT")

    def get_coverage_cells(self, task_id: str) -> Set[str]:
        """Get coverage cells as set of 'row_col' strings"""
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT cell_row, cell_col FROM coverage_data WHERE task_id = ?",
                (task_id,)
            ).fetchall()
            return {f"{row['cell_row']}_{row['cell_col']}" for row in rows}

    def get_coverage_count(self, task_id: str) -> int:
        """Get number of coverage cells for a task"""
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM coverage_data WHERE task_id = ?",
                (task_id,)
            ).fetchone()
            return row["cnt"] if row else 0

    # =========================================================================
    # Delete Operations
    # =========================================================================

    def delete_customer(self, customer_id: str):
        """Delete a customer and all related data"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM customers WHERE id = ?", (customer_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (customer_id,))
            conn.commit()

    def delete_farmer(self, farmer_id: str):
        """Delete a farmer and all related data"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM farmers WHERE id = ?", (farmer_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (farmer_id,))
            conn.commit()

    def delete_farm(self, farm_id: str):
        """Delete a farm and all related data"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM farms WHERE id = ?", (farm_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (farm_id,))
            conn.commit()

    def delete_partfield(self, partfield_id: str):
        """Delete a partfield and all related data"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM partfields WHERE id = ?", (partfield_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (partfield_id,))
            conn.commit()

    def delete_task(self, task_id: str):
        """Delete a task and all related data"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (task_id,))
            conn.commit()

    def delete_guidance_line(self, line_id: str):
        """Delete a guidance line"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM guidance_lines WHERE id = ?", (line_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (line_id,))
            conn.commit()

    def delete_headland(self, headland_id: str):
        """Delete a headland"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM headlands WHERE id = ?", (headland_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (headland_id,))
            conn.commit()

    def delete_device(self, device_id: str):
        """Delete a device"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM devices WHERE id = ?", (device_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (device_id,))
            conn.commit()

    def delete_product(self, product_id: str):
        """Delete a product"""
        with self._get_connection() as conn:
            conn.execute("DELETE FROM products WHERE id = ?", (product_id,))
            conn.execute("DELETE FROM id_table WHERE id = ?", (product_id,))
            conn.commit()


# =============================================================================
# Helper Functions
# =============================================================================


def _parse_datetime(value: Optional[str]) -> Optional[datetime]:
    """Parse datetime string to datetime object"""
    if not value:
        return None
    try:
        # Try ISO format first
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        try:
            # Try SQLite default format
            return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            return None
