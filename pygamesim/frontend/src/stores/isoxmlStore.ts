import { create } from 'zustand';
import type {
  ISOFarm,
  ISOPartfield,
  ISOTask,
  ISOGuidanceLine,
  ISODevice,
  ISOProduct,
  ISOHeadland,
} from '../types/simulation';

const API_BASE = 'http://localhost:8001/api/isoxml';

interface ISOXMLStore {
  // Data
  farms: ISOFarm[];
  partfields: ISOPartfield[];
  tasks: ISOTask[];
  guidanceLines: ISOGuidanceLine[];
  devices: ISODevice[];
  products: ISOProduct[];
  headlands: ISOHeadland[];

  // Selected items
  selectedFarmId: string | null;
  selectedPartfieldId: string | null;
  selectedTaskId: string | null;

  // Loading state
  loading: boolean;
  error: string | null;

  // Selection actions
  selectFarm: (farmId: string | null) => void;
  selectPartfield: (partfieldId: string | null) => void;
  selectTask: (taskId: string | null) => void;

  // Data fetching
  setup: () => Promise<void>;
  fetchFarms: () => Promise<void>;
  fetchPartfields: (farmId?: string) => Promise<void>;
  fetchTasks: (partfieldId?: string) => Promise<void>;
  fetchGuidanceLines: (partfieldId?: string) => Promise<void>;
  fetchDevices: () => Promise<void>;
  fetchProducts: () => Promise<void>;
  fetchAll: () => Promise<void>;

  // CRUD operations
  createFarm: (farmerId: string, name: string) => Promise<ISOFarm | null>;
  createPartfield: (farmId: string, name: string, boundary?: { latitude: number; longitude: number }[]) => Promise<ISOPartfield | null>;
  createTask: (partfieldId: string, name: string, taskType?: string) => Promise<ISOTask | null>;
  createGuidanceLine: (partfieldId: string, points: { latitude: number; longitude: number }[], spacingM?: number) => Promise<ISOGuidanceLine | null>;
  updateTaskStatus: (taskId: string, status: string) => Promise<void>;
  deleteTask: (taskId: string) => Promise<void>;
  deletePartfield: (partfieldId: string) => Promise<void>;

  // Import/Export
  importFile: (file: File) => Promise<void>;
  exportData: (farmId?: string) => Promise<Blob>;
}

export const useISOXMLStore = create<ISOXMLStore>((set, get) => ({
  // Data
  farms: [],
  partfields: [],
  tasks: [],
  guidanceLines: [],
  devices: [],
  products: [],
  headlands: [],

  // Selected items
  selectedFarmId: null,
  selectedPartfieldId: null,
  selectedTaskId: null,

  // Loading state
  loading: false,
  error: null,

  // Selection actions
  selectFarm: (farmId) => {
    set({ selectedFarmId: farmId, selectedPartfieldId: null, selectedTaskId: null });
    if (farmId) {
      get().fetchPartfields(farmId);
    }
  },

  selectPartfield: (partfieldId) => {
    set({ selectedPartfieldId: partfieldId, selectedTaskId: null });
    if (partfieldId) {
      get().fetchTasks(partfieldId);
      get().fetchGuidanceLines(partfieldId);
    }
  },

  selectTask: (taskId) => set({ selectedTaskId: taskId }),

  // Data fetching
  setup: async () => {
    set({ loading: true, error: null });
    try {
      const res = await fetch(`${API_BASE}/setup`, { method: 'POST' });
      if (!res.ok) throw new Error('Setup failed');
      await get().fetchFarms();
    } catch (e) {
      set({ error: (e as Error).message });
    } finally {
      set({ loading: false });
    }
  },

  fetchFarms: async () => {
    try {
      const res = await fetch(`${API_BASE}/farms`);
      if (!res.ok) throw new Error('Failed to fetch farms');
      const data = await res.json();
      set({ farms: data.farms });

      // Auto-select first farm if none selected
      const { selectedFarmId } = get();
      if (!selectedFarmId && data.farms.length > 0) {
        get().selectFarm(data.farms[0].id);
      }
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchPartfields: async (farmId?: string) => {
    try {
      const url = farmId ? `${API_BASE}/partfields?farm_id=${farmId}` : `${API_BASE}/partfields`;
      const res = await fetch(url);
      if (!res.ok) throw new Error('Failed to fetch partfields');
      const data = await res.json();
      set({ partfields: data.partfields });
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchTasks: async (partfieldId?: string) => {
    try {
      const url = partfieldId ? `${API_BASE}/tasks?partfield_id=${partfieldId}` : `${API_BASE}/tasks`;
      const res = await fetch(url);
      if (!res.ok) throw new Error('Failed to fetch tasks');
      const data = await res.json();
      set({ tasks: data.tasks });
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchGuidanceLines: async (partfieldId?: string) => {
    try {
      const url = partfieldId ? `${API_BASE}/guidance-lines?partfield_id=${partfieldId}` : `${API_BASE}/guidance-lines`;
      const res = await fetch(url);
      if (!res.ok) throw new Error('Failed to fetch guidance lines');
      const data = await res.json();
      set({ guidanceLines: data.guidance_lines });
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchDevices: async () => {
    try {
      const res = await fetch(`${API_BASE}/devices`);
      if (!res.ok) throw new Error('Failed to fetch devices');
      const data = await res.json();
      set({ devices: data.devices });
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchProducts: async () => {
    try {
      const res = await fetch(`${API_BASE}/products`);
      if (!res.ok) throw new Error('Failed to fetch products');
      const data = await res.json();
      set({ products: data.products });
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  fetchAll: async () => {
    set({ loading: true, error: null });
    try {
      await Promise.all([
        get().fetchFarms(),
        get().fetchDevices(),
        get().fetchProducts(),
      ]);
    } finally {
      set({ loading: false });
    }
  },

  // CRUD operations
  createFarm: async (farmerId, name) => {
    try {
      const res = await fetch(`${API_BASE}/farms`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ farmer_id: farmerId, name }),
      });
      if (!res.ok) throw new Error('Failed to create farm');
      const farm = await res.json();
      await get().fetchFarms();
      return farm;
    } catch (e) {
      set({ error: (e as Error).message });
      return null;
    }
  },

  createPartfield: async (farmId, name, boundary) => {
    try {
      const res = await fetch(`${API_BASE}/partfields`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ farm_id: farmId, name, boundary }),
      });
      if (!res.ok) throw new Error('Failed to create partfield');
      const partfield = await res.json();
      await get().fetchPartfields(farmId);
      return partfield;
    } catch (e) {
      set({ error: (e as Error).message });
      return null;
    }
  },

  createTask: async (partfieldId, name, taskType = 'other') => {
    try {
      const res = await fetch(`${API_BASE}/tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ partfield_id: partfieldId, name, task_type: taskType }),
      });
      if (!res.ok) throw new Error('Failed to create task');
      const task = await res.json();
      await get().fetchTasks(partfieldId);
      return task;
    } catch (e) {
      set({ error: (e as Error).message });
      return null;
    }
  },

  createGuidanceLine: async (partfieldId, points, spacingM = 6.0) => {
    try {
      const res = await fetch(`${API_BASE}/guidance-lines`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          partfield_id: partfieldId,
          line_type: 'straight_ab',
          points,
          spacing_m: spacingM,
        }),
      });
      if (!res.ok) throw new Error('Failed to create guidance line');
      const line = await res.json();
      await get().fetchGuidanceLines(partfieldId);
      return line;
    } catch (e) {
      set({ error: (e as Error).message });
      return null;
    }
  },

  updateTaskStatus: async (taskId, status) => {
    try {
      const res = await fetch(`${API_BASE}/tasks/${taskId}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      if (!res.ok) throw new Error('Failed to update task status');
      const { selectedPartfieldId } = get();
      if (selectedPartfieldId) {
        await get().fetchTasks(selectedPartfieldId);
      }
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  deleteTask: async (taskId) => {
    try {
      const res = await fetch(`${API_BASE}/tasks/${taskId}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Failed to delete task');
      const { selectedPartfieldId } = get();
      if (selectedPartfieldId) {
        await get().fetchTasks(selectedPartfieldId);
      }
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  deletePartfield: async (partfieldId) => {
    try {
      const res = await fetch(`${API_BASE}/partfields/${partfieldId}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Failed to delete partfield');
      const { selectedFarmId } = get();
      if (selectedFarmId) {
        await get().fetchPartfields(selectedFarmId);
      }
    } catch (e) {
      set({ error: (e as Error).message });
    }
  },

  // Import/Export
  importFile: async (file) => {
    set({ loading: true, error: null });
    try {
      const formData = new FormData();
      formData.append('file', file);

      const res = await fetch(`${API_BASE}/import`, {
        method: 'POST',
        body: formData,
      });
      if (!res.ok) throw new Error('Import failed');

      await get().fetchAll();
    } catch (e) {
      set({ error: (e as Error).message });
    } finally {
      set({ loading: false });
    }
  },

  exportData: async (farmId) => {
    const url = farmId ? `${API_BASE}/export?farm_id=${farmId}` : `${API_BASE}/export`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Export failed');
    return await res.blob();
  },
}));
