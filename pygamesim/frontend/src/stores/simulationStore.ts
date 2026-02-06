import { create } from 'zustand';
import type {
  SimulationState,
  CoverageStrip,
  GuidanceLine,
  Command,
} from '../types/simulation';

interface SimulationStore {
  // Connection state
  connected: boolean;
  setConnected: (connected: boolean) => void;

  // Simulation state
  state: SimulationState | null;
  setState: (state: SimulationState) => void;

  // Coverage data
  coverage: CoverageStrip[];
  setCoverage: (coverage: CoverageStrip[]) => void;
  addCoverage: (strips: CoverageStrip[]) => void;

  // Guidance lines
  guidanceLines: GuidanceLine[];
  setGuidanceLines: (lines: GuidanceLine[]) => void;

  // Control inputs
  throttle: number;
  steering: number;
  setThrottle: (throttle: number) => void;
  setSteering: (steering: number) => void;

  // WebSocket
  ws: WebSocket | null;
  setWs: (ws: WebSocket | null) => void;
  sendCommand: (command: Command) => void;

  // Actions
  setAPoint: () => void;
  setBPoint: () => void;
  clearGuidance: () => void;
  toggleImplement: () => void;
  reset: () => void;
}

export const useSimulationStore = create<SimulationStore>((set, get) => ({
  // Connection state
  connected: false,
  setConnected: (connected) => set({ connected }),

  // Simulation state
  state: null,
  setState: (state) => set({ state }),

  // Coverage data
  coverage: [],
  setCoverage: (coverage) => set({ coverage }),
  addCoverage: (strips) =>
    set((s) => ({
      coverage: [...s.coverage, ...strips.filter((s) => s !== null)],
    })),

  // Guidance lines
  guidanceLines: [],
  setGuidanceLines: (guidanceLines) => set({ guidanceLines }),

  // Control inputs
  throttle: 0,
  steering: 0,
  setThrottle: (throttle) => set({ throttle }),
  setSteering: (steering) => set({ steering }),

  // WebSocket
  ws: null,
  setWs: (ws) => set({ ws }),
  sendCommand: (command) => {
    const { ws, connected } = get();
    if (ws && connected) {
      ws.send(JSON.stringify(command));
    }
  },

  // Actions
  setAPoint: () => get().sendCommand({ type: 'setA' }),
  setBPoint: () => get().sendCommand({ type: 'setB' }),
  clearGuidance: () => get().sendCommand({ type: 'clearGuidance' }),
  toggleImplement: () => get().sendCommand({ type: 'toggleImplement' }),
  reset: () => {
    get().sendCommand({ type: 'reset' });
    set({ coverage: [], guidanceLines: [] });
  },
}));
