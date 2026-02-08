import { configureStore } from '@reduxjs/toolkit'
import isoxmlFileReducer from './commonStores/isoxmlFile'
import visualSettingsReducer from './commonStores/visualSettings'
import mapReducer from './commonStores/map'
import guidanceReducer from './commonStores/guidanceState'
import fieldReducer from './commonStores/fieldState'
import equipmentReducer from './commonStores/equipmentState'

const store = configureStore({
    reducer: {
        isoxmlFile: isoxmlFileReducer,
        visualSettings: visualSettingsReducer,
        map: mapReducer,
        guidance: guidanceReducer,
        fields: fieldReducer,
        equipment: equipmentReducer
    }
})

export type RootState = ReturnType<typeof store.getState>

export type AppDispatch = typeof store.dispatch

export default store