import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit'
import { RootState } from '../store'
import {
    initDatabase,
    getAllFields,
    saveField as dbSaveField,
    deleteField as dbDeleteField,
    getActiveFieldId,
    setActiveFieldId as dbSetActiveFieldId,
    generateFieldId,
    generateABLineId,
    FieldData
} from '../utils/database'

export interface ABLine {
    id: string
    name: string
    pointA: [number, number] | null  // [lng, lat]
    pointB: [number, number] | null
    swathWidth: number  // meters
    numSwathsLeft: number
    numSwathsRight: number
}

export interface Field {
    id: string
    name: string
    abLines: ABLine[]
    boundary: [number, number][] | null  // completed polygon coordinates (closed ring)
}

// Convert from DB format to Redux format
function fieldFromDb(data: FieldData): Field {
    return {
        id: data.id,
        name: data.name,
        boundary: data.boundary,
        abLines: data.abLines.map(ab => ({
            id: ab.id,
            name: ab.name,
            pointA: ab.pointA,
            pointB: ab.pointB,
            swathWidth: ab.swathWidth,
            numSwathsLeft: ab.numSwathsLeft,
            numSwathsRight: ab.numSwathsRight
        }))
    }
}

// Convert from Redux format to DB format
function fieldToDb(field: Field): FieldData {
    return {
        id: field.id,
        name: field.name,
        boundary: field.boundary,
        abLines: field.abLines.map(ab => ({
            id: ab.id,
            fieldId: field.id,
            name: ab.name,
            pointA: ab.pointA,
            pointB: ab.pointB,
            swathWidth: ab.swathWidth,
            numSwathsLeft: ab.numSwathsLeft,
            numSwathsRight: ab.numSwathsRight
        }))
    }
}

export type EditMode = 'none' | 'settingA' | 'settingB' | 'drawingBoundary'

interface FieldState {
    fields: Field[]
    activeFieldId: string | null
    activeABLineId: string | null
    editMode: EditMode
    showSwaths: boolean
    // Temporary boundary points while drawing (before completing)
    boundaryDrawingPoints: [number, number][]
    isInitialized: boolean
}

const initialState: FieldState = {
    fields: [],
    activeFieldId: null,
    activeABLineId: null,
    editMode: 'none',
    showSwaths: true,
    boundaryDrawingPoints: [],
    isInitialized: false
}

// Async thunk to load fields from database
export const initializeFields = createAsyncThunk(
    'fields/initialize',
    async () => {
        // Ensure database is initialized first
        await initDatabase()
        const fields = getAllFields().map(fieldFromDb)
        const activeFieldId = getActiveFieldId()
        return { fields, activeFieldId }
    }
)

// Helper to save a field to database (called after state changes)
function persistField(field: Field) {
    dbSaveField(fieldToDb(field))
}

function persistActiveFieldId(id: string | null) {
    dbSetActiveFieldId(id)
}

export const fieldSlice = createSlice({
    name: 'fields',
    initialState,
    reducers: {
        // Create field and immediately enter boundary drawing mode
        createField: (state, action: PayloadAction<{ name?: string }>) => {
            const newField: Field = {
                id: generateFieldId(),
                name: action.payload.name || `Field ${state.fields.length + 1}`,
                abLines: [],
                boundary: null
            }
            state.fields.push(newField)
            state.activeFieldId = newField.id
            state.activeABLineId = null
            state.editMode = 'drawingBoundary'
            state.boundaryDrawingPoints = []
            // Note: Don't persist yet - field has no boundary
        },

        deleteField: (state, action: PayloadAction<string>) => {
            dbDeleteField(action.payload)
            state.fields = state.fields.filter(f => f.id !== action.payload)
            if (state.activeFieldId === action.payload) {
                state.activeFieldId = state.fields.length > 0 ? state.fields[0].id : null
                state.activeABLineId = null
                state.editMode = 'none'
                state.boundaryDrawingPoints = []
            }
            persistActiveFieldId(state.activeFieldId)
        },

        renameField: (state, action: PayloadAction<{ fieldId: string; name: string }>) => {
            const field = state.fields.find(f => f.id === action.payload.fieldId)
            if (field) {
                field.name = action.payload.name
                persistField(field)
            }
        },

        setActiveField: (state, action: PayloadAction<string | null>) => {
            state.activeFieldId = action.payload
            state.activeABLineId = null
            state.editMode = 'none'
            state.boundaryDrawingPoints = []
            persistActiveFieldId(action.payload)
        },

        // Boundary drawing actions
        addBoundaryPoint: (state, action: PayloadAction<[number, number]>) => {
            if (state.editMode === 'drawingBoundary') {
                state.boundaryDrawingPoints.push(action.payload)
            }
        },

        undoBoundaryPoint: (state) => {
            if (state.editMode === 'drawingBoundary' && state.boundaryDrawingPoints.length > 0) {
                state.boundaryDrawingPoints.pop()
            }
        },

        completeBoundary: (state) => {
            if (state.editMode === 'drawingBoundary' &&
                state.activeFieldId &&
                state.boundaryDrawingPoints.length >= 3) {
                const field = state.fields.find(f => f.id === state.activeFieldId)
                if (field) {
                    // Close the polygon by adding first point at end if needed
                    const points = [...state.boundaryDrawingPoints]
                    const first = points[0]
                    const last = points[points.length - 1]
                    if (first[0] !== last[0] || first[1] !== last[1]) {
                        points.push([...first] as [number, number])
                    }
                    field.boundary = points
                    state.editMode = 'none'
                    state.boundaryDrawingPoints = []
                    // Persist the completed field
                    persistField(field)
                    persistActiveFieldId(field.id)
                }
            }
        },

        cancelBoundaryDrawing: (state) => {
            if (state.editMode === 'drawingBoundary' && state.activeFieldId) {
                // If no boundary was completed, delete the field
                const field = state.fields.find(f => f.id === state.activeFieldId)
                if (field && !field.boundary) {
                    state.fields = state.fields.filter(f => f.id !== state.activeFieldId)
                    state.activeFieldId = state.fields.length > 0 ? state.fields[0].id : null
                }
                state.editMode = 'none'
                state.boundaryDrawingPoints = []
            }
        },

        startEditBoundary: (state, action: PayloadAction<string>) => {
            const field = state.fields.find(f => f.id === action.payload)
            if (field) {
                state.activeFieldId = action.payload
                state.activeABLineId = null
                state.editMode = 'drawingBoundary'
                // Load existing boundary points (without the closing point)
                if (field.boundary && field.boundary.length > 0) {
                    const points = [...field.boundary]
                    // Remove closing point if it matches first point
                    if (points.length > 1) {
                        const first = points[0]
                        const last = points[points.length - 1]
                        if (first[0] === last[0] && first[1] === last[1]) {
                            points.pop()
                        }
                    }
                    state.boundaryDrawingPoints = points
                } else {
                    state.boundaryDrawingPoints = []
                }
            }
        },

        // AB Line actions
        createABLine: (state, action: PayloadAction<{ fieldId: string; name?: string }>) => {
            const field = state.fields.find(f => f.id === action.payload.fieldId)
            if (field && field.boundary) {  // Only allow if field has boundary
                const newABLine: ABLine = {
                    id: generateABLineId(),
                    name: action.payload.name || `AB Line ${field.abLines.length + 1}`,
                    pointA: null,
                    pointB: null,
                    swathWidth: 12.192,  // 40 ft default
                    numSwathsLeft: 5,
                    numSwathsRight: 5
                }
                field.abLines.push(newABLine)
                state.activeABLineId = newABLine.id
                state.editMode = 'settingA'
                persistField(field)
            }
        },

        deleteABLine: (state, action: PayloadAction<{ fieldId: string; abLineId: string }>) => {
            const field = state.fields.find(f => f.id === action.payload.fieldId)
            if (field) {
                field.abLines = field.abLines.filter(ab => ab.id !== action.payload.abLineId)
                if (state.activeABLineId === action.payload.abLineId) {
                    state.activeABLineId = null
                    state.editMode = 'none'
                }
                persistField(field)
            }
        },

        setActiveABLine: (state, action: PayloadAction<string | null>) => {
            state.activeABLineId = action.payload
            if (action.payload) {
                // Find the AB line and check if it needs points set
                for (const field of state.fields) {
                    const abLine = field.abLines.find(ab => ab.id === action.payload)
                    if (abLine) {
                        state.activeFieldId = field.id
                        if (!abLine.pointA) {
                            state.editMode = 'settingA'
                        } else if (!abLine.pointB) {
                            state.editMode = 'settingB'
                        } else {
                            state.editMode = 'none'
                        }
                        break
                    }
                }
            } else {
                state.editMode = 'none'
            }
        },

        setPointA: (state, action: PayloadAction<{ abLineId: string; point: [number, number] }>) => {
            for (const field of state.fields) {
                const abLine = field.abLines.find(ab => ab.id === action.payload.abLineId)
                if (abLine) {
                    abLine.pointA = action.payload.point
                    state.editMode = 'settingB'
                    persistField(field)
                    break
                }
            }
        },

        setPointB: (state, action: PayloadAction<{ abLineId: string; point: [number, number] }>) => {
            for (const field of state.fields) {
                const abLine = field.abLines.find(ab => ab.id === action.payload.abLineId)
                if (abLine) {
                    abLine.pointB = action.payload.point
                    state.editMode = 'none'
                    persistField(field)
                    break
                }
            }
        },

        updateABLineSettings: (state, action: PayloadAction<{
            abLineId: string
            swathWidth?: number
            numSwathsLeft?: number
            numSwathsRight?: number
            name?: string
        }>) => {
            for (const field of state.fields) {
                const abLine = field.abLines.find(ab => ab.id === action.payload.abLineId)
                if (abLine) {
                    if (action.payload.swathWidth !== undefined) {
                        abLine.swathWidth = action.payload.swathWidth
                    }
                    if (action.payload.numSwathsLeft !== undefined) {
                        abLine.numSwathsLeft = action.payload.numSwathsLeft
                    }
                    if (action.payload.numSwathsRight !== undefined) {
                        abLine.numSwathsRight = action.payload.numSwathsRight
                    }
                    if (action.payload.name !== undefined) {
                        abLine.name = action.payload.name
                    }
                    persistField(field)
                    break
                }
            }
        },

        setEditMode: (state, action: PayloadAction<EditMode>) => {
            state.editMode = action.payload
        },

        setShowSwaths: (state, action: PayloadAction<boolean>) => {
            state.showSwaths = action.payload
        },

        resetABLine: (state, action: PayloadAction<string>) => {
            for (const field of state.fields) {
                const abLine = field.abLines.find(ab => ab.id === action.payload)
                if (abLine) {
                    abLine.pointA = null
                    abLine.pointB = null
                    state.editMode = 'settingA'
                    persistField(field)
                    break
                }
            }
        }
    },
    extraReducers: (builder) => {
        builder.addCase(initializeFields.fulfilled, (state, action) => {
            state.fields = action.payload.fields
            state.activeFieldId = action.payload.activeFieldId
            state.isInitialized = true
            console.log(`[Fields] Loaded ${action.payload.fields.length} fields from database`)
        })
    }
})

export const {
    createField,
    deleteField,
    renameField,
    setActiveField,
    addBoundaryPoint,
    undoBoundaryPoint,
    completeBoundary,
    cancelBoundaryDrawing,
    startEditBoundary,
    createABLine,
    deleteABLine,
    setActiveABLine,
    setPointA,
    setPointB,
    updateABLineSettings,
    setEditMode,
    setShowSwaths,
    resetABLine
} = fieldSlice.actions

export default fieldSlice.reducer

// Selectors
export const fieldsSelector = (state: RootState) => state.fields.fields
export const activeFieldIdSelector = (state: RootState) => state.fields.activeFieldId
export const activeABLineIdSelector = (state: RootState) => state.fields.activeABLineId
export const editModeSelector = (state: RootState) => state.fields.editMode
export const showSwathsSelector = (state: RootState) => state.fields.showSwaths
export const boundaryDrawingPointsSelector = (state: RootState) => state.fields.boundaryDrawingPoints

export const activeFieldSelector = (state: RootState) => {
    if (!state.fields.activeFieldId) return null
    return state.fields.fields.find(f => f.id === state.fields.activeFieldId) || null
}

export const activeABLineSelector = (state: RootState) => {
    if (!state.fields.activeABLineId) return null
    for (const field of state.fields.fields) {
        const abLine = field.abLines.find(ab => ab.id === state.fields.activeABLineId)
        if (abLine) return abLine
    }
    return null
}
