"""
FastAPI WebSocket server for pygamesim.

Runs the simulation loop and broadcasts state to connected clients.
Includes ISOXML support for field/task management.
"""

import asyncio
import json
import math
import time
import os
from contextlib import asynccontextmanager
from dataclasses import asdict
from typing import List, Optional, Dict, Any
from io import BytesIO

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
import uvicorn

from ..sensord import NMEASimulator
from ..localizer import MachineGeometry, ImplementGeometry, Localizer, Pose
from ..guidance import ABGuidance
from ..vehicle import VehicleSimulator
from ..isoxml import (
    DatabaseManager,
    ISOXMLParser,
    ISOXMLExporter,
    TaskType,
    TaskStatus,
    GuidanceLineType,
    DeviceType,
    ProductType,
    BoundaryPoint,
    GuidancePoint,
)


# =============================================================================
# Pydantic Models for API
# =============================================================================


class CreateFarmRequest(BaseModel):
    farmer_id: str
    name: str
    address: Optional[str] = None
    notes: Optional[str] = None


class CreatePartfieldRequest(BaseModel):
    farm_id: str
    name: str
    season: Optional[str] = None
    crop_type: Optional[str] = None
    boundary: Optional[List[Dict[str, float]]] = None
    notes: Optional[str] = None


class UpdateBoundaryRequest(BaseModel):
    boundary: List[Dict[str, float]]


class CreateTaskRequest(BaseModel):
    partfield_id: str
    name: str
    task_type: str = "other"
    device_id: Optional[str] = None
    product_id: Optional[str] = None
    guidance_line_id: Optional[str] = None
    headland_id: Optional[str] = None
    notes: Optional[str] = None


class UpdateTaskStatusRequest(BaseModel):
    status: str


class CreateGuidanceLineRequest(BaseModel):
    partfield_id: str
    line_type: str = "straight_ab"
    points: List[Dict[str, float]]
    spacing_m: float = 6.0
    heading_deg: Optional[float] = None


class CreateHeadlandRequest(BaseModel):
    partfield_id: str
    boundary: List[Dict[str, float]]
    offset_m: float
    direction: str = "inward"


class CreateDeviceRequest(BaseModel):
    name: str
    device_type: str = "tractor"
    wheelbase: Optional[float] = None
    work_width: Optional[float] = None


class CreateProductRequest(BaseModel):
    name: str
    product_type: str = "other"
    unit: Optional[str] = None
    notes: Optional[str] = None


class SetupRequest(BaseModel):
    """Quick setup request for creating default customer/farmer/farm"""
    customer_name: str = "Default Customer"
    farmer_name: str = "Default Farmer"
    farm_name: str = "Default Farm"


class SimulationState:
    """Manages the simulation state."""

    def __init__(self):
        # Configuration
        self.machine_geom = MachineGeometry(
            antenna_pivot=1.0,
            hitch_length=1.5
        )
        self.implement_geom = ImplementGeometry(
            pivot_offset=5.0,
            width=6.0,
            is_pivoting=True
        )

        # Components
        self.vehicle = VehicleSimulator(wheelbase=2.5)
        self.gnss = NMEASimulator(update_rate_hz=10.0, cep_meters=0.1)
        self.localizer = Localizer(self.machine_geom, self.implement_geom)
        self.guidance = ABGuidance(swath_width=self.implement_geom.width)

        # State
        self.implement_active = False
        self.coverage_strips: List[dict] = []  # For rendering coverage
        self.sim_time = 0.0
        self.last_update = time.time()

        # Control inputs (set by clients)
        self.throttle = 0.0
        self.steering = 0.0

    def update(self, dt: float) -> dict:
        """Update simulation and return state for clients."""
        # Apply controls
        self.vehicle.throttle = self.throttle
        self.vehicle.steering_input = self.steering

        # Update vehicle
        self.vehicle.update(dt)
        self.sim_time += dt

        # Get antenna position and generate GNSS fix
        antenna_x, antenna_y = self.vehicle.get_antenna_position(
            self.machine_geom.antenna_pivot
        )
        fix = self.gnss.update(antenna_x, antenna_y, self.sim_time)

        if fix:
            self.localizer.update(fix, self.sim_time)

            if self.guidance.ab_line:
                self.guidance.update(self.localizer.implement_pose)

            # Record coverage
            if self.implement_active and self.localizer.filtered_speed > 0.3:
                self.coverage_strips.append({
                    'x': self.localizer.implement_pose.x,
                    'y': self.localizer.implement_pose.y,
                    'heading': self.localizer.implement_pose.heading,
                    'width': self.implement_geom.width
                })

        return self.get_state()

    def get_state(self) -> dict:
        """Get current state for broadcasting."""
        ab_line = None
        if self.guidance.ab_line and self.guidance.ab_line.is_valid:
            ab_line = {
                'a': {'x': self.guidance.ab_line.a_x, 'y': self.guidance.ab_line.a_y},
                'b': {'x': self.guidance.ab_line.b_x, 'y': self.guidance.ab_line.b_y},
                'heading': self.guidance.ab_line.heading
            }

        return {
            'timestamp': self.sim_time,
            'vehicle': {
                'x': self.vehicle.state.x,
                'y': self.vehicle.state.y,
                'heading': self.vehicle.state.heading,
                'speed': self.vehicle.state.speed,
                'steeringAngle': self.vehicle.state.steering_angle
            },
            'localizer': {
                'machine': {
                    'x': self.localizer.machine_pose.x,
                    'y': self.localizer.machine_pose.y,
                    'heading': self.localizer.machine_pose.heading
                },
                'hitch': {
                    'x': self.localizer.hitch_pose.x,
                    'y': self.localizer.hitch_pose.y,
                    'heading': self.localizer.hitch_pose.heading
                },
                'implement': {
                    'x': self.localizer.implement_pose.x,
                    'y': self.localizer.implement_pose.y,
                    'heading': self.localizer.implement_pose.heading
                },
                'speed': self.localizer.filtered_speed,
                'isInitialized': self.localizer.is_initialized
            },
            'guidance': {
                'abLine': ab_line,
                'crossTrackError': self.guidance.cross_track_error,
                'headingError': self.guidance.heading_error,
                'activeLineIndex': self.guidance.active_line_index,
                'swathWidth': self.guidance.swath_width
            },
            'implement': {
                'active': self.implement_active,
                'width': self.implement_geom.width
            },
            'coverageCount': len(self.coverage_strips)
        }

    def get_coverage(self, last_index: int = 0) -> List[dict]:
        """Get coverage strips since last_index."""
        return self.coverage_strips[last_index:]

    def get_guidance_lines(self, render_distance: float = 100.0) -> List[dict]:
        """Get visible AB guidance lines."""
        if not self.localizer.is_initialized:
            return []

        lines = self.guidance.get_visible_lines(
            self.localizer.machine_pose.x,
            self.localizer.machine_pose.y,
            render_distance
        )

        return [
            {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'active': active}
            for x1, y1, x2, y2, active in lines
        ]

    def set_a_point(self):
        """Set A point at current position."""
        if self.localizer.is_initialized:
            self.guidance.set_a_point(
                self.localizer.machine_pose.x,
                self.localizer.machine_pose.y
            )
            return True
        return False

    def set_b_point(self):
        """Set B point at current position."""
        if self.localizer.is_initialized and self.guidance.ab_line:
            self.guidance.set_b_point(
                self.localizer.machine_pose.x,
                self.localizer.machine_pose.y
            )
            return self.guidance.ab_line.is_valid
        return False

    def clear_guidance(self):
        """Clear AB line."""
        self.guidance.clear()

    def toggle_implement(self):
        """Toggle implement on/off."""
        if self.implement_active:
            self.coverage_strips.append(None)  # Break marker
        self.implement_active = not self.implement_active
        return self.implement_active

    def reset(self):
        """Reset simulation."""
        self.vehicle.set_position(0, 0, 0)
        self.vehicle.state.speed = 0
        self.localizer.is_initialized = False
        self.localizer.position_history.clear()
        self.guidance.clear()
        self.coverage_strips.clear()
        self.implement_active = False
        self.sim_time = 0.0


# Global simulation state
sim = SimulationState()
connected_clients: List[WebSocket] = []
simulation_task: Optional[asyncio.Task] = None

# Database manager for ISOXML data
db = DatabaseManager.shared()


async def simulation_loop():
    """Main simulation loop running at 60Hz."""
    last_time = time.time()

    while True:
        current_time = time.time()
        dt = current_time - last_time
        if dt > 0.1:
            dt = 0.1  # Cap delta time
        last_time = current_time

        # Update simulation
        state = sim.update(dt)

        # Broadcast to all clients
        if connected_clients:
            message = json.dumps({
                'type': 'state',
                'data': state
            })

            disconnected = []
            for client in connected_clients:
                try:
                    await client.send_text(message)
                except:
                    disconnected.append(client)

            for client in disconnected:
                connected_clients.remove(client)

        # Target 60Hz
        await asyncio.sleep(1/60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start/stop simulation loop with app."""
    global simulation_task
    simulation_task = asyncio.create_task(simulation_loop())
    yield
    simulation_task.cancel()
    try:
        await simulation_task
    except asyncio.CancelledError:
        pass


app = FastAPI(lifespan=lifespan)

# CORS for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time communication."""
    await websocket.accept()
    connected_clients.append(websocket)

    # Send initial state
    await websocket.send_text(json.dumps({
        'type': 'init',
        'data': {
            'state': sim.get_state(),
            'coverage': sim.coverage_strips,
            'guidanceLines': sim.get_guidance_lines()
        }
    }))

    try:
        while True:
            # Receive commands from client
            data = await websocket.receive_text()
            message = json.loads(data)

            cmd = message.get('type')

            if cmd == 'control':
                # Update vehicle controls
                sim.throttle = message.get('throttle', 0.0)
                sim.steering = message.get('steering', 0.0)

            elif cmd == 'setA':
                success = sim.set_a_point()
                await websocket.send_text(json.dumps({
                    'type': 'event',
                    'event': 'aPointSet',
                    'success': success
                }))

            elif cmd == 'setB':
                success = sim.set_b_point()
                await websocket.send_text(json.dumps({
                    'type': 'event',
                    'event': 'bPointSet',
                    'success': success,
                    'guidanceLines': sim.get_guidance_lines() if success else []
                }))

            elif cmd == 'clearGuidance':
                sim.clear_guidance()
                await websocket.send_text(json.dumps({
                    'type': 'event',
                    'event': 'guidanceCleared'
                }))

            elif cmd == 'toggleImplement':
                active = sim.toggle_implement()
                await websocket.send_text(json.dumps({
                    'type': 'event',
                    'event': 'implementToggled',
                    'active': active
                }))

            elif cmd == 'reset':
                sim.reset()
                await websocket.send_text(json.dumps({
                    'type': 'event',
                    'event': 'reset'
                }))

            elif cmd == 'getCoverage':
                last_index = message.get('lastIndex', 0)
                await websocket.send_text(json.dumps({
                    'type': 'coverage',
                    'data': sim.get_coverage(last_index),
                    'totalCount': len(sim.coverage_strips)
                }))

            elif cmd == 'getGuidanceLines':
                await websocket.send_text(json.dumps({
                    'type': 'guidanceLines',
                    'data': sim.get_guidance_lines()
                }))

    except WebSocketDisconnect:
        connected_clients.remove(websocket)
    except Exception as e:
        print(f"WebSocket error: {e}")
        if websocket in connected_clients:
            connected_clients.remove(websocket)


@app.get("/api/state")
async def get_state():
    """Get current simulation state (REST fallback)."""
    return sim.get_state()


@app.post("/api/reset")
async def reset():
    """Reset simulation."""
    sim.reset()
    return {"status": "ok"}


# =============================================================================
# ISOXML API Endpoints
# =============================================================================


# -----------------------------------------------------------------------------
# Setup & Initialization
# -----------------------------------------------------------------------------


@app.post("/api/isoxml/setup")
async def setup_isoxml(request: SetupRequest):
    """Create default customer, farmer, and farm for quick start."""
    # Check if any customers exist
    customers = db.get_all_customers()
    if customers:
        # Return existing setup
        customer = customers[0]
        farmers = db.get_farmers_for_customer(customer.id)
        farmer = farmers[0] if farmers else None
        farms = db.get_farms_for_farmer(farmer.id) if farmer else []
        farm = farms[0] if farms else None

        return {
            "status": "exists",
            "customer_id": customer.id,
            "farmer_id": farmer.id if farmer else None,
            "farm_id": farm.id if farm else None
        }

    # Create new setup
    customer = db.create_customer(request.customer_name)
    if not customer:
        raise HTTPException(status_code=500, detail="Failed to create customer")

    farmer = db.create_farmer(customer.id, request.farmer_name)
    if not farmer:
        raise HTTPException(status_code=500, detail="Failed to create farmer")

    farm = db.create_farm(farmer.id, request.farm_name)
    if not farm:
        raise HTTPException(status_code=500, detail="Failed to create farm")

    return {
        "status": "created",
        "customer_id": customer.id,
        "farmer_id": farmer.id,
        "farm_id": farm.id
    }


# -----------------------------------------------------------------------------
# Farms
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/farms")
async def list_farms():
    """List all farms."""
    farms = db.get_all_farms()
    return {
        "farms": [
            {
                "id": f.id,
                "farmer_id": f.farmer_id,
                "name": f.name,
                "address": f.address,
                "notes": f.notes
            }
            for f in farms
        ]
    }


@app.get("/api/isoxml/farms/{farm_id}")
async def get_farm(farm_id: str):
    """Get a specific farm."""
    farm = db.get_farm(farm_id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found")

    return {
        "id": farm.id,
        "farmer_id": farm.farmer_id,
        "name": farm.name,
        "address": farm.address,
        "notes": farm.notes
    }


@app.post("/api/isoxml/farms")
async def create_farm(request: CreateFarmRequest):
    """Create a new farm."""
    farm = db.create_farm(request.farmer_id, request.name, request.address, request.notes)
    if not farm:
        raise HTTPException(status_code=500, detail="Failed to create farm")

    return {
        "id": farm.id,
        "farmer_id": farm.farmer_id,
        "name": farm.name
    }


@app.delete("/api/isoxml/farms/{farm_id}")
async def delete_farm(farm_id: str):
    """Delete a farm."""
    db.delete_farm(farm_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Partfields (Fields)
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/partfields")
async def list_partfields(farm_id: Optional[str] = None):
    """List partfields, optionally filtered by farm."""
    if farm_id:
        partfields = db.get_partfields_for_farm(farm_id)
    else:
        partfields = db.get_all_partfields()

    return {
        "partfields": [
            {
                "id": pf.id,
                "farm_id": pf.farm_id,
                "name": pf.name,
                "area_m2": pf.area_m2,
                "area_hectares": pf.area_hectares,
                "season": pf.season,
                "crop_type": pf.crop_type,
                "boundary": [{"latitude": p.latitude, "longitude": p.longitude} for p in pf.boundary] if pf.boundary else None,
                "notes": pf.notes
            }
            for pf in partfields
        ]
    }


@app.get("/api/isoxml/partfields/{partfield_id}")
async def get_partfield(partfield_id: str):
    """Get a specific partfield."""
    pf = db.get_partfield(partfield_id)
    if not pf:
        raise HTTPException(status_code=404, detail="Partfield not found")

    return {
        "id": pf.id,
        "farm_id": pf.farm_id,
        "name": pf.name,
        "area_m2": pf.area_m2,
        "area_hectares": pf.area_hectares,
        "season": pf.season,
        "crop_type": pf.crop_type,
        "boundary": [{"latitude": p.latitude, "longitude": p.longitude} for p in pf.boundary] if pf.boundary else None,
        "notes": pf.notes
    }


@app.post("/api/isoxml/partfields")
async def create_partfield(request: CreatePartfieldRequest):
    """Create a new partfield."""
    boundary = None
    if request.boundary:
        boundary = [BoundaryPoint(p["latitude"], p["longitude"]) for p in request.boundary]

    pf = db.create_partfield(
        request.farm_id,
        request.name,
        request.season,
        request.crop_type,
        boundary,
        request.notes
    )
    if not pf:
        raise HTTPException(status_code=500, detail="Failed to create partfield")

    return {
        "id": pf.id,
        "farm_id": pf.farm_id,
        "name": pf.name,
        "area_m2": pf.area_m2
    }


@app.put("/api/isoxml/partfields/{partfield_id}/boundary")
async def update_partfield_boundary(partfield_id: str, request: UpdateBoundaryRequest):
    """Update partfield boundary."""
    pf = db.get_partfield(partfield_id)
    if not pf:
        raise HTTPException(status_code=404, detail="Partfield not found")

    boundary = [BoundaryPoint(p["latitude"], p["longitude"]) for p in request.boundary]

    # Calculate area
    pf.boundary = boundary
    pf.calculate_area()

    db.update_partfield_boundary(partfield_id, boundary, pf.area_m2)

    return {
        "id": partfield_id,
        "area_m2": pf.area_m2,
        "boundary_points": len(boundary)
    }


@app.delete("/api/isoxml/partfields/{partfield_id}")
async def delete_partfield(partfield_id: str):
    """Delete a partfield."""
    db.delete_partfield(partfield_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Tasks
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/tasks")
async def list_tasks(partfield_id: Optional[str] = None, status: Optional[str] = None):
    """List tasks, optionally filtered by partfield or status."""
    if partfield_id:
        tasks = db.get_tasks_for_partfield(partfield_id)
    else:
        tasks = db.get_all_tasks()

    if status:
        try:
            filter_status = TaskStatus(status)
            tasks = [t for t in tasks if t.status == filter_status]
        except ValueError:
            pass

    return {
        "tasks": [
            {
                "id": t.id,
                "partfield_id": t.partfield_id,
                "name": t.name,
                "task_type": t.task_type.value,
                "status": t.status.value,
                "device_id": t.device_id,
                "product_id": t.product_id,
                "guidance_line_id": t.guidance_line_id,
                "headland_id": t.headland_id,
                "notes": t.notes
            }
            for t in tasks
        ]
    }


@app.get("/api/isoxml/tasks/{task_id}")
async def get_task(task_id: str):
    """Get a specific task."""
    task = db.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    return {
        "id": task.id,
        "partfield_id": task.partfield_id,
        "name": task.name,
        "task_type": task.task_type.value,
        "status": task.status.value,
        "device_id": task.device_id,
        "product_id": task.product_id,
        "guidance_line_id": task.guidance_line_id,
        "headland_id": task.headland_id,
        "notes": task.notes
    }


@app.post("/api/isoxml/tasks")
async def create_task(request: CreateTaskRequest):
    """Create a new task."""
    try:
        task_type = TaskType(request.task_type)
    except ValueError:
        task_type = TaskType.OTHER

    task = db.create_task(
        request.partfield_id,
        request.name,
        task_type,
        request.device_id,
        request.product_id,
        request.guidance_line_id,
        request.headland_id,
        request.notes
    )
    if not task:
        raise HTTPException(status_code=500, detail="Failed to create task")

    return {
        "id": task.id,
        "partfield_id": task.partfield_id,
        "name": task.name,
        "task_type": task.task_type.value,
        "status": task.status.value
    }


@app.put("/api/isoxml/tasks/{task_id}/status")
async def update_task_status(task_id: str, request: UpdateTaskStatusRequest):
    """Update task status."""
    task = db.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    try:
        status = TaskStatus(request.status)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid status: {request.status}")

    db.update_task_status(task_id, status)

    return {"id": task_id, "status": status.value}


@app.delete("/api/isoxml/tasks/{task_id}")
async def delete_task(task_id: str):
    """Delete a task."""
    db.delete_task(task_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Guidance Lines
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/guidance-lines")
async def list_guidance_lines(partfield_id: Optional[str] = None):
    """List guidance lines, optionally filtered by partfield."""
    if partfield_id:
        lines = db.get_guidance_lines_for_partfield(partfield_id)
    else:
        # Get all guidance lines (need to iterate partfields)
        lines = []
        for pf in db.get_all_partfields():
            lines.extend(db.get_guidance_lines_for_partfield(pf.id))

    return {
        "guidance_lines": [
            {
                "id": line.id,
                "partfield_id": line.partfield_id,
                "type": line.type.value,
                "points": [{"latitude": p.latitude, "longitude": p.longitude} for p in line.points],
                "spacing_m": line.spacing_m,
                "heading_deg": line.heading_deg
            }
            for line in lines
        ]
    }


@app.get("/api/isoxml/guidance-lines/{line_id}")
async def get_guidance_line(line_id: str):
    """Get a specific guidance line."""
    line = db.get_guidance_line(line_id)
    if not line:
        raise HTTPException(status_code=404, detail="Guidance line not found")

    return {
        "id": line.id,
        "partfield_id": line.partfield_id,
        "type": line.type.value,
        "points": [{"latitude": p.latitude, "longitude": p.longitude} for p in line.points],
        "spacing_m": line.spacing_m,
        "heading_deg": line.heading_deg
    }


@app.post("/api/isoxml/guidance-lines")
async def create_guidance_line(request: CreateGuidanceLineRequest):
    """Create a new guidance line."""
    try:
        line_type = GuidanceLineType(request.line_type)
    except ValueError:
        line_type = GuidanceLineType.STRAIGHT_AB

    points = [GuidancePoint(p["latitude"], p["longitude"]) for p in request.points]

    line = db.create_guidance_line(
        request.partfield_id,
        line_type,
        points,
        request.spacing_m,
        request.heading_deg
    )
    if not line:
        raise HTTPException(status_code=500, detail="Failed to create guidance line")

    return {
        "id": line.id,
        "partfield_id": line.partfield_id,
        "type": line.type.value,
        "spacing_m": line.spacing_m
    }


@app.delete("/api/isoxml/guidance-lines/{line_id}")
async def delete_guidance_line(line_id: str):
    """Delete a guidance line."""
    db.delete_guidance_line(line_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Headlands
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/headlands")
async def list_headlands(partfield_id: Optional[str] = None):
    """List headlands, optionally filtered by partfield."""
    if partfield_id:
        headlands = db.get_headlands_for_partfield(partfield_id)
    else:
        headlands = []
        for pf in db.get_all_partfields():
            headlands.extend(db.get_headlands_for_partfield(pf.id))

    return {
        "headlands": [
            {
                "id": h.id,
                "partfield_id": h.partfield_id,
                "boundary": [{"latitude": p.latitude, "longitude": p.longitude} for p in h.boundary],
                "offset_m": h.offset_m,
                "direction": h.direction
            }
            for h in headlands
        ]
    }


@app.post("/api/isoxml/headlands")
async def create_headland(request: CreateHeadlandRequest):
    """Create a new headland."""
    boundary = [BoundaryPoint(p["latitude"], p["longitude"]) for p in request.boundary]

    headland = db.create_headland(
        request.partfield_id,
        boundary,
        request.offset_m,
        request.direction
    )
    if not headland:
        raise HTTPException(status_code=500, detail="Failed to create headland")

    return {
        "id": headland.id,
        "partfield_id": headland.partfield_id,
        "offset_m": headland.offset_m
    }


@app.delete("/api/isoxml/headlands/{headland_id}")
async def delete_headland(headland_id: str):
    """Delete a headland."""
    db.delete_headland(headland_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Devices
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/devices")
async def list_devices():
    """List all devices."""
    devices = db.get_all_devices()
    return {
        "devices": [
            {
                "id": d.id,
                "name": d.name,
                "device_type": d.device_type.value,
                "config": d.config.to_dict() if d.config else None
            }
            for d in devices
        ]
    }


@app.post("/api/isoxml/devices")
async def create_device(request: CreateDeviceRequest):
    """Create a new device."""
    try:
        device_type = DeviceType(request.device_type)
    except ValueError:
        device_type = DeviceType.OTHER

    from ..isoxml.models import DeviceConfig
    config = None
    if request.wheelbase or request.work_width:
        config = DeviceConfig(
            wheelbase=request.wheelbase,
            work_width=request.work_width
        )

    device = db.create_device(request.name, device_type, config)
    if not device:
        raise HTTPException(status_code=500, detail="Failed to create device")

    return {
        "id": device.id,
        "name": device.name,
        "device_type": device.device_type.value
    }


@app.delete("/api/isoxml/devices/{device_id}")
async def delete_device(device_id: str):
    """Delete a device."""
    db.delete_device(device_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Products
# -----------------------------------------------------------------------------


@app.get("/api/isoxml/products")
async def list_products():
    """List all products."""
    products = db.get_all_products()
    return {
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "product_type": p.product_type.value,
                "unit": p.unit,
                "notes": p.notes
            }
            for p in products
        ]
    }


@app.post("/api/isoxml/products")
async def create_product(request: CreateProductRequest):
    """Create a new product."""
    try:
        product_type = ProductType(request.product_type)
    except ValueError:
        product_type = ProductType.OTHER

    product = db.create_product(request.name, product_type, request.unit, request.notes)
    if not product:
        raise HTTPException(status_code=500, detail="Failed to create product")

    return {
        "id": product.id,
        "name": product.name,
        "product_type": product.product_type.value
    }


@app.delete("/api/isoxml/products/{product_id}")
async def delete_product(product_id: str):
    """Delete a product."""
    db.delete_product(product_id)
    return {"status": "deleted"}


# -----------------------------------------------------------------------------
# Import/Export
# -----------------------------------------------------------------------------


@app.post("/api/isoxml/import")
async def import_isoxml(file: UploadFile = File(...)):
    """Import ISOXML TaskData file (ZIP or XML)."""
    content = await file.read()

    parser = ISOXMLParser(db)

    try:
        if file.filename and file.filename.lower().endswith(".zip"):
            # Save to temp file for ZIP processing
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
                tmp.write(content)
                tmp_path = tmp.name

            try:
                result = parser.parse_file(tmp_path, import_to_db=True)
            finally:
                os.unlink(tmp_path)
        else:
            result = parser.parse_bytes(content, import_to_db=True)

        return {
            "status": "imported",
            "counts": result
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Import failed: {str(e)}")


@app.get("/api/isoxml/export")
async def export_isoxml(
    farm_id: Optional[str] = Query(None),
    as_zip: bool = Query(True)
):
    """Export ISOXML TaskData file."""
    exporter = ISOXMLExporter(db)

    farm_ids = [farm_id] if farm_id else None
    content = exporter.export_to_bytes(farm_ids=farm_ids, as_zip=as_zip)

    if as_zip:
        return StreamingResponse(
            BytesIO(content),
            media_type="application/zip",
            headers={"Content-Disposition": "attachment; filename=TASKDATA.ZIP"}
        )
    else:
        return StreamingResponse(
            BytesIO(content),
            media_type="application/xml",
            headers={"Content-Disposition": "attachment; filename=TASKDATA.XML"}
        )


# -----------------------------------------------------------------------------
# Task Logs & Coverage
# -----------------------------------------------------------------------------


@app.post("/api/isoxml/tasks/{task_id}/logs")
async def add_task_log(
    task_id: str,
    latitude: float = Query(...),
    longitude: float = Query(...),
    heading: Optional[float] = Query(None),
    speed: Optional[float] = Query(None)
):
    """Add a log entry to a task."""
    task = db.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    db.add_task_log(task_id, latitude, longitude, heading, speed)
    return {"status": "logged"}


@app.get("/api/isoxml/tasks/{task_id}/logs")
async def get_task_logs(task_id: str, limit: Optional[int] = Query(None)):
    """Get task logs."""
    task = db.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    logs = db.get_task_logs(task_id, limit)
    return {
        "logs": [
            {
                "id": log.id,
                "timestamp": log.timestamp.isoformat(),
                "latitude": log.latitude,
                "longitude": log.longitude,
                "heading": log.heading,
                "speed": log.speed,
                "data": log.data
            }
            for log in logs
        ]
    }


@app.get("/api/isoxml/tasks/{task_id}/coverage")
async def get_task_coverage(task_id: str):
    """Get coverage data for a task."""
    task = db.get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    cells = db.get_coverage_cells(task_id)
    count = db.get_coverage_count(task_id)

    return {
        "task_id": task_id,
        "cell_count": count,
        "cells": list(cells)
    }


def run_server(host: str = "0.0.0.0", port: int = 8001):
    """Run the server."""
    uvicorn.run(app, host=host, port=port)


if __name__ == "__main__":
    run_server()
