import { createSlice, createAsyncThunk } from '@reduxjs/toolkit'
import {
    initDatabase,
    getAllVehicles,
    getAllImplements,
    saveVehicle,
    saveImplement,
    deleteVehicle as dbDeleteVehicle,
    deleteImplement as dbDeleteImplement,
    getActiveVehicleId,
    getActiveImplementId,
    setActiveVehicleId as dbSetActiveVehicleId,
    setActiveImplementId as dbSetActiveImplementId,
    generateVehicleId,
    generateImplementId,
    VehicleConfig,
    ImplementConfig,
    AntennaConfig
} from '../utils/database'

// Re-export types for convenience
export type { VehicleConfig, ImplementConfig, AntennaConfig }

interface EquipmentState {
    vehicles: VehicleConfig[]
    implements: ImplementConfig[]
    activeVehicleId: string | null
    activeImplementId: string | null
    isLoading: boolean
    isInitialized: boolean
    error: string | null
}

const initialState: EquipmentState = {
    vehicles: [],
    implements: [],
    activeVehicleId: null,
    activeImplementId: null,
    isLoading: false,
    isInitialized: false,
    error: null
}

// Async thunks for database operations

export const initializeEquipment = createAsyncThunk(
    'equipment/initialize',
    async () => {
        await initDatabase()
        const vehicles = getAllVehicles()
        const implements_ = getAllImplements()
        const activeVehicleId = getActiveVehicleId()
        const activeImplementId = getActiveImplementId()
        return { vehicles, implements: implements_, activeVehicleId, activeImplementId }
    }
)

export const createVehicle = createAsyncThunk(
    'equipment/createVehicle',
    async (vehicle: Omit<VehicleConfig, 'id'>) => {
        const id = generateVehicleId()
        const newVehicle: VehicleConfig = { ...vehicle, id }
        saveVehicle(newVehicle)
        return newVehicle
    }
)

export const updateVehicle = createAsyncThunk(
    'equipment/updateVehicle',
    async (vehicle: VehicleConfig) => {
        saveVehicle(vehicle)
        return vehicle
    }
)

export const removeVehicle = createAsyncThunk(
    'equipment/removeVehicle',
    async ({ id, vehicles, activeVehicleId }: { id: string; vehicles: VehicleConfig[]; activeVehicleId: string | null }) => {
        dbDeleteVehicle(id)
        // If we're deleting the active vehicle, switch to another one
        if (activeVehicleId === id) {
            const remaining = vehicles.filter(v => v.id !== id)
            if (remaining.length > 0) {
                dbSetActiveVehicleId(remaining[0].id)
                return { id, newActiveId: remaining[0].id }
            }
            return { id, newActiveId: null }
        }
        return { id, newActiveId: undefined }
    }
)

export const createImplement = createAsyncThunk(
    'equipment/createImplement',
    async (implement: Omit<ImplementConfig, 'id'>) => {
        const id = generateImplementId()
        const newImplement: ImplementConfig = { ...implement, id }
        saveImplement(newImplement)
        return newImplement
    }
)

export const updateImplement = createAsyncThunk(
    'equipment/updateImplement',
    async (implement: ImplementConfig) => {
        saveImplement(implement)
        return implement
    }
)

export const removeImplement = createAsyncThunk(
    'equipment/removeImplement',
    async ({ id, implements_, activeImplementId }: { id: string; implements_: ImplementConfig[]; activeImplementId: string | null }) => {
        dbDeleteImplement(id)
        // If we're deleting the active implement, switch to another one
        if (activeImplementId === id) {
            const remaining = implements_.filter(i => i.id !== id)
            if (remaining.length > 0) {
                dbSetActiveImplementId(remaining[0].id)
                return { id, newActiveId: remaining[0].id }
            }
            return { id, newActiveId: null }
        }
        return { id, newActiveId: undefined }
    }
)

export const setActiveVehicle = createAsyncThunk(
    'equipment/setActiveVehicle',
    async (id: string) => {
        dbSetActiveVehicleId(id)
        return id
    }
)

export const setActiveImplement = createAsyncThunk(
    'equipment/setActiveImplement',
    async (id: string) => {
        dbSetActiveImplementId(id)
        return id
    }
)

export const equipmentSlice = createSlice({
    name: 'equipment',
    initialState,
    reducers: {
        clearError: (state) => {
            state.error = null
        }
    },
    extraReducers: (builder) => {
        // Initialize
        builder.addCase(initializeEquipment.pending, (state) => {
            state.isLoading = true
            state.error = null
        })
        builder.addCase(initializeEquipment.fulfilled, (state, action) => {
            state.isLoading = false
            state.isInitialized = true
            state.vehicles = action.payload.vehicles
            state.implements = action.payload.implements
            state.activeVehicleId = action.payload.activeVehicleId
            state.activeImplementId = action.payload.activeImplementId
        })
        builder.addCase(initializeEquipment.rejected, (state, action) => {
            state.isLoading = false
            state.error = action.error.message || 'Failed to initialize equipment database'
        })

        // Create vehicle
        builder.addCase(createVehicle.fulfilled, (state, action) => {
            state.vehicles.push(action.payload)
        })

        // Update vehicle
        builder.addCase(updateVehicle.fulfilled, (state, action) => {
            const index = state.vehicles.findIndex(v => v.id === action.payload.id)
            if (index !== -1) {
                state.vehicles[index] = action.payload
            }
        })

        // Remove vehicle
        builder.addCase(removeVehicle.fulfilled, (state, action) => {
            state.vehicles = state.vehicles.filter(v => v.id !== action.payload.id)
            if (action.payload.newActiveId !== undefined) {
                state.activeVehicleId = action.payload.newActiveId
            }
        })

        // Create implement
        builder.addCase(createImplement.fulfilled, (state, action) => {
            state.implements.push(action.payload)
        })

        // Update implement
        builder.addCase(updateImplement.fulfilled, (state, action) => {
            const index = state.implements.findIndex(i => i.id === action.payload.id)
            if (index !== -1) {
                state.implements[index] = action.payload
            }
        })

        // Remove implement
        builder.addCase(removeImplement.fulfilled, (state, action) => {
            state.implements = state.implements.filter(i => i.id !== action.payload.id)
            if (action.payload.newActiveId !== undefined) {
                state.activeImplementId = action.payload.newActiveId
            }
        })

        // Set active vehicle
        builder.addCase(setActiveVehicle.fulfilled, (state, action) => {
            state.activeVehicleId = action.payload
        })

        // Set active implement
        builder.addCase(setActiveImplement.fulfilled, (state, action) => {
            state.activeImplementId = action.payload
        })
    }
})

export const { clearError } = equipmentSlice.actions

export default equipmentSlice.reducer

// Type for state containing equipment slice (avoids circular dependency with store.ts)
type StateWithEquipment = { equipment: EquipmentState }

// Selectors
export const vehiclesSelector = (state: StateWithEquipment) => state.equipment.vehicles
export const implementsSelector = (state: StateWithEquipment) => state.equipment.implements
export const activeVehicleIdSelector = (state: StateWithEquipment) => state.equipment.activeVehicleId
export const activeImplementIdSelector = (state: StateWithEquipment) => state.equipment.activeImplementId
export const isEquipmentLoadingSelector = (state: StateWithEquipment) => state.equipment.isLoading
export const isEquipmentInitializedSelector = (state: StateWithEquipment) => state.equipment.isInitialized
export const equipmentErrorSelector = (state: StateWithEquipment) => state.equipment.error

export const activeVehicleSelector = (state: StateWithEquipment) => {
    if (!state.equipment.activeVehicleId) return null
    return state.equipment.vehicles.find(v => v.id === state.equipment.activeVehicleId) || null
}

export const activeImplementSelector = (state: StateWithEquipment) => {
    if (!state.equipment.activeImplementId) return null
    return state.equipment.implements.find(i => i.id === state.equipment.activeImplementId) || null
}
