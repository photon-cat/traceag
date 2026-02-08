import { createSlice, PayloadAction } from '@reduxjs/toolkit'
import { RootState } from '../store'

export type GuidanceMode = 'off' | 'settingA' | 'settingB' | 'complete'

interface GuidanceState {
    mode: GuidanceMode
    pointA: [number, number] | null  // [lng, lat]
    pointB: [number, number] | null
    swathWidth: number  // meters
    numSwathsLeft: number
    numSwathsRight: number
    showSwaths: boolean
    lineName: string
}

const initialState: GuidanceState = {
    mode: 'off',
    pointA: null,
    pointB: null,
    swathWidth: 12.192,  // 40 ft in meters (common US implement width)
    numSwathsLeft: 5,
    numSwathsRight: 5,
    showSwaths: true,
    lineName: 'AB Line 1'
}

export const guidanceSlice = createSlice({
    name: 'guidance',
    initialState,
    reducers: {
        startGuidanceMode: (state) => {
            state.mode = 'settingA'
            state.pointA = null
            state.pointB = null
        },
        setPointA: (state, action: PayloadAction<[number, number]>) => {
            state.pointA = action.payload
            state.mode = 'settingB'
        },
        setPointB: (state, action: PayloadAction<[number, number]>) => {
            state.pointB = action.payload
            state.mode = 'complete'
        },
        setSwathWidth: (state, action: PayloadAction<number>) => {
            state.swathWidth = action.payload
        },
        setNumSwathsLeft: (state, action: PayloadAction<number>) => {
            state.numSwathsLeft = action.payload
        },
        setNumSwathsRight: (state, action: PayloadAction<number>) => {
            state.numSwathsRight = action.payload
        },
        setShowSwaths: (state, action: PayloadAction<boolean>) => {
            state.showSwaths = action.payload
        },
        setLineName: (state, action: PayloadAction<string>) => {
            state.lineName = action.payload
        },
        resetGuidance: (state) => {
            state.mode = 'off'
            state.pointA = null
            state.pointB = null
        },
        cancelGuidance: (state) => {
            state.mode = 'off'
            state.pointA = null
            state.pointB = null
        }
    }
})

export const {
    startGuidanceMode,
    setPointA,
    setPointB,
    setSwathWidth,
    setNumSwathsLeft,
    setNumSwathsRight,
    setShowSwaths,
    setLineName,
    resetGuidance,
    cancelGuidance
} = guidanceSlice.actions

export default guidanceSlice.reducer

// Selectors
export const guidanceModeSelector = (state: RootState) => state.guidance.mode
export const guidancePointASelector = (state: RootState) => state.guidance.pointA
export const guidancePointBSelector = (state: RootState) => state.guidance.pointB
export const guidanceSwathWidthSelector = (state: RootState) => state.guidance.swathWidth
export const guidanceNumSwathsLeftSelector = (state: RootState) => state.guidance.numSwathsLeft
export const guidanceNumSwathsRightSelector = (state: RootState) => state.guidance.numSwathsRight
export const guidanceShowSwathsSelector = (state: RootState) => state.guidance.showSwaths
export const guidanceLineNameSelector = (state: RootState) => state.guidance.lineName
export const guidanceStateSelector = (state: RootState) => state.guidance
