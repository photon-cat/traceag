// Position and pose types
export interface Position {
  x: number;
  y: number;
}

export interface Pose extends Position {
  heading: number;
}

// Vehicle state from simulation
export interface VehicleState {
  x: number;
  y: number;
  heading: number;
  speed: number;
  steeringAngle: number;
}

// Localizer state
export interface LocalizerState {
  machine: Pose;
  hitch: Pose;
  implement: Pose;
  speed: number;
  isInitialized: boolean;
}

// AB Line
export interface ABLine {
  a: Position;
  b: Position;
  heading: number;
}

// Guidance state
export interface GuidanceState {
  abLine: ABLine | null;
  crossTrackError: number;
  headingError: number;
  activeLineIndex: number;
  swathWidth: number;
}

// Implement state
export interface ImplementState {
  active: boolean;
  width: number;
}

// Coverage strip
export interface CoverageStrip {
  x: number;
  y: number;
  heading: number;
  width: number;
}

// Guidance line for rendering
export interface GuidanceLine {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  active: boolean;
}

// Full simulation state
export interface SimulationState {
  timestamp: number;
  vehicle: VehicleState;
  localizer: LocalizerState;
  guidance: GuidanceState;
  implement: ImplementState;
  coverageCount: number;
}

// WebSocket message types
export type WSMessageType =
  | 'state'
  | 'init'
  | 'event'
  | 'coverage'
  | 'guidanceLines';

export interface WSMessage {
  type: WSMessageType;
  data?: unknown;
  event?: string;
  success?: boolean;
}

// Control commands
export interface ControlCommand {
  type: 'control';
  throttle: number;
  steering: number;
}

export type Command =
  | ControlCommand
  | { type: 'setA' }
  | { type: 'setB' }
  | { type: 'clearGuidance' }
  | { type: 'toggleImplement' }
  | { type: 'reset' }
  | { type: 'getCoverage'; lastIndex: number }
  | { type: 'getGuidanceLines' };

// =============================================================================
// ISOXML Types
// =============================================================================

export interface ISOFarm {
  id: string;
  farmer_id: string;
  name: string;
  address?: string;
  notes?: string;
}

export interface ISOPartfield {
  id: string;
  farm_id: string;
  name: string;
  area_m2?: number;
  area_hectares?: number;
  season?: string;
  crop_type?: string;
  boundary?: { latitude: number; longitude: number }[];
  notes?: string;
}

export interface ISOTask {
  id: string;
  partfield_id: string;
  name: string;
  task_type: string;
  status: string;
  device_id?: string;
  product_id?: string;
  guidance_line_id?: string;
  headland_id?: string;
  notes?: string;
}

export interface ISOGuidanceLine {
  id: string;
  partfield_id: string;
  type: string;
  points: { latitude: number; longitude: number }[];
  spacing_m: number;
  heading_deg?: number;
}

export interface ISODevice {
  id: string;
  name: string;
  device_type: string;
  config?: {
    wheelbase?: number;
    work_width?: number;
  };
}

export interface ISOProduct {
  id: string;
  name: string;
  product_type: string;
  unit?: string;
  notes?: string;
}

export interface ISOHeadland {
  id: string;
  partfield_id: string;
  boundary: { latitude: number; longitude: number }[];
  offset_m: number;
  direction: string;
}
