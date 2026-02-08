import React, { useCallback, useEffect, useRef, useState } from 'react'
import { useSelector, useDispatch } from 'react-redux'
import Box from '@mui/material/Box'
import { WebMercatorViewport } from '@deck.gl/core'
import DeckGL from '@deck.gl/react'
import {GeoJsonLayer } from '@deck.gl/layers'
import { ExtendedGrid, Task } from 'isoxml'
import {
    gridsVisibilitySelector,
    partfieldsVisibilitySelector,
    timeLogsExcludeOutliersSelector,
    timeLogsFillMissingValuesSelector,
    timeLogsSelectedValueSelector,
    timeLogsVisibilitySelector
} from '../commonStores/visualSettings'
import { isoxmlFileGridsInfoSelector } from '../commonStores/isoxmlFile'
import ISOXMLGridLayer from '../mapLayers/GridLayer'
import { fitBoundsSelector } from '../commonStores/map'
import { formatValue, getGridValue } from '../utils'
import { OSMBasemap, OSMCopyright } from '../mapLayers/OSMBaseLayer'
import { getISOXMLManager, getPartfieldGeoJSON, getTimeLogGeoJSON, getTimeLogsCache, getTimeLogValuesRange } from '../commonStores/isoxmlFileInfo'
import TimeLogLayer from '../mapLayers/TimeLogLayer'
import PartfieldLayer from '../mapLayers/PartfieldLayer'
import ABLineLayer from '../mapLayers/ABLineLayer'
import FieldBoundaryLayer from '../mapLayers/FieldBoundaryLayer'
import {
    fieldsSelector,
    activeFieldIdSelector,
    activeABLineIdSelector,
    editModeSelector,
    showSwathsSelector,
    boundaryDrawingPointsSelector,
    setPointA,
    setPointB,
    addBoundaryPoint
} from '../commonStores/fieldState'
import { AppDispatch } from '../store'

interface TooltipState {
    x: number,
    y: number,
    value: string,
    layerType: 'grid' | 'timelog',
    layerId: string
    timeLogValueKey?: string
}

export function Map() {
    const dispatch: AppDispatch = useDispatch()
    const [tooltip, setTooltip] = useState<TooltipState>(null)

    // Default to Lynchburg, VA
    const [initialViewState, setInitialViewState] = useState<any>({
        longitude: -79.1422,
        latitude: 37.4138,
        zoom: 13
    })

    // Field state
    const fields = useSelector(fieldsSelector)
    const activeFieldId = useSelector(activeFieldIdSelector)
    const activeABLineId = useSelector(activeABLineIdSelector)
    const editMode = useSelector(editModeSelector)
    const showSwaths = useSelector(showSwathsSelector)
    const boundaryDrawingPoints = useSelector(boundaryDrawingPointsSelector)

    const isoxmlManager = getISOXMLManager()
    const timeLogsCache = getTimeLogsCache()

    const fitBounds = useSelector(fitBoundsSelector)
    const gridsInfo = useSelector(isoxmlFileGridsInfoSelector)
    const visibleGrids = useSelector(gridsVisibilitySelector)

    const visibleTimeLogs = useSelector(timeLogsVisibilitySelector)
    const timeLogsSelectedValue = useSelector(timeLogsSelectedValueSelector)
    const timeLogsExcludeOutliers = useSelector(timeLogsExcludeOutliersSelector)
    const timeLogsFillMissingValues = useSelector(timeLogsFillMissingValuesSelector)

    const visiblePartfields = useSelector(partfieldsVisibilitySelector)

    const partfieldLayers = Object.keys(visiblePartfields)
        .filter(key => visiblePartfields[key])
        .map(partfieldId => {
            const geoJSON = getPartfieldGeoJSON(partfieldId)
            return new PartfieldLayer(partfieldId, geoJSON)
        })

    const gridLayers = Object.keys(visibleGrids)
        .filter(taskId => visibleGrids[taskId])
        .map(taskId => {
            const task = isoxmlManager.getEntityByXmlId<Task>(taskId)

            return new ISOXMLGridLayer(
                taskId,
                task.attributes.Grid[0] as ExtendedGrid,
                task.attributes.TreatmentZone,
                gridsInfo[taskId]
            )
        })

    const timeLogLayers = Object.keys(visibleTimeLogs)
        .filter(key => visibleTimeLogs[key])
        .flatMap(timeLogId => {
            const valueKey = timeLogsSelectedValue[timeLogId]
            if (!valueKey) {
                return []
            }
            const excludeOutliers = timeLogsExcludeOutliers[timeLogId]
            const fillValues = timeLogsFillMissingValues[timeLogId]
            const geoJSON = getTimeLogGeoJSON(timeLogId, fillValues)

            const { minValue, maxValue } = getTimeLogValuesRange(timeLogId, valueKey, excludeOutliers)

            return [new TimeLogLayer(timeLogId, geoJSON, valueKey, minValue, maxValue)]
        })

    const viewStateRef = useRef(null)

    const onViewStateChange = useCallback(e => {
        viewStateRef.current = e.viewState
        setTooltip(null)
    }, [])

    const onMapClick = useCallback((pickInfo: any) => {
        // Handle boundary drawing clicks
        if (editMode === 'drawingBoundary') {
            const coordinate = pickInfo.coordinate
            if (coordinate) {
                const point: [number, number] = [coordinate[0], coordinate[1]]
                dispatch(addBoundaryPoint(point))
            }
            return
        }

        // Handle AB line point setting clicks
        if (activeABLineId && (editMode === 'settingA' || editMode === 'settingB')) {
            const coordinate = pickInfo.coordinate
            if (coordinate) {
                const point: [number, number] = [coordinate[0], coordinate[1]]
                if (editMode === 'settingA') {
                    dispatch(setPointA({ abLineId: activeABLineId, point }))
                } else if (editMode === 'settingB') {
                    dispatch(setPointB({ abLineId: activeABLineId, point }))
                }
            }
            return
        }

        if (!pickInfo.layer) {
            setTooltip(null)
            return
        }

        if (pickInfo.layer instanceof ISOXMLGridLayer) {
            const pixel = pickInfo.bitmap.pixel
            const taskId = pickInfo.layer.id

            const task = isoxmlManager.getEntityByXmlId<Task>(taskId)

            const grid = task.attributes.Grid[0] as ExtendedGrid

            const value = getGridValue(grid, pixel[0], pixel[1])
            if (value) {
                const gridInfo = gridsInfo[taskId]
                const formattedValue = formatValue(value, gridInfo)

                setTooltip({
                    x: pickInfo.x,
                    y: pickInfo.y,
                    value: formattedValue,
                    layerType: 'grid',
                    layerId: taskId
                })
            } else {
                setTooltip(null)
            }
        } else if (pickInfo.layer instanceof GeoJsonLayer) {
            const timeLogId = pickInfo.layer.id
            const valueKey = timeLogsSelectedValue[timeLogId]
            const value = pickInfo.object?.properties?.[valueKey]
            if (value !== undefined) {
                const timeLogInfo = timeLogsCache[timeLogId]?.valuesInfo?.find(info => info.valueKey === valueKey)
                if (timeLogInfo) {
                    const formattedValue = formatValue(value, timeLogInfo)
                    setTooltip({
                        x: pickInfo.x,
                        y: pickInfo.y,
                        value: formattedValue,
                        layerType: 'timelog',
                        layerId: timeLogId,
                        timeLogValueKey: valueKey
                    })
                    return
                }
            }
            setTooltip(null)
        } else {
            setTooltip(null)
        }
    }, [isoxmlManager, gridsInfo, timeLogsSelectedValue, timeLogsCache, editMode, activeABLineId, dispatch])

    useEffect(() => {
        if (fitBounds) {
            const viewport = new WebMercatorViewport(viewStateRef.current)
            const {longitude, latitude, zoom} = viewport.fitBounds(
                [fitBounds.slice(0, 2), fitBounds.slice(2, 4)],
                {padding: 8}
            ) as any
            setInitialViewState({
                longitude,
                latitude,
                zoom: Math.min(20, zoom),
                pitch: 0,
                bearing: 0,
                __triggerUpdate: Math.random() // This property is used to force DeckGL to update the viewState
            })
            setTooltip(null)
        }
    }, [fitBounds])

    let isTooltipVisible = false
    if (tooltip) {
        if (tooltip.layerType === 'grid') {
            isTooltipVisible = !!visibleGrids[tooltip.layerId]
        } else {
            isTooltipVisible = !!visibleTimeLogs[tooltip.layerId] &&
                timeLogsSelectedValue[tooltip.layerId] === tooltip.timeLogValueKey
        }
    }

    // Create AB Line layers for all fields
    const abLineLayers = fields.flatMap(field =>
        field.abLines
            .filter(abLine => abLine.pointA)  // Only show AB lines with at least point A
            .map(abLine => new ABLineLayer({
                id: `abline-${abLine.id}`,
                pointA: abLine.pointA,
                pointB: abLine.pointB,
                swathWidth: abLine.swathWidth,
                numSwathsLeft: abLine.numSwathsLeft,
                numSwathsRight: abLine.numSwathsRight,
                showSwaths: showSwaths && abLine.pointA && abLine.pointB
            } as any))
    )

    // Create Field Boundary layer
    const fieldBoundaryLayer = new FieldBoundaryLayer({
        id: 'field-boundaries',
        fields: fields,
        activeFieldId: activeFieldId,
        boundaryDrawingPoints: boundaryDrawingPoints,
        isDrawingBoundary: editMode === 'drawingBoundary'
    } as any)

    // Combine all layers
    const allLayers = [
        OSMBasemap,
        ...gridLayers,
        ...partfieldLayers,
        ...timeLogLayers,
        fieldBoundaryLayer,
        ...abLineLayers
    ]

    // Determine cursor style based on edit mode
    const getCursor = () => {
        if (editMode === 'settingA' || editMode === 'settingB' || editMode === 'drawingBoundary') {
            return 'crosshair'
        }
        return 'grab'
    }

    return (<>
        <DeckGL
            initialViewState={initialViewState}
            controller={true}
            layers={allLayers}
            onViewStateChange={onViewStateChange}
            onClick={onMapClick}
            getCursor={getCursor}
        >
            <OSMCopyright />
            {isTooltipVisible && (<>
                <Box
                    sx={{
                        backgroundColor: 'blue',
                        position: 'absolute',
                        width: 4,
                        height: 4,
                        borderRadius: 3,
                        transform: 'translate(-50%, -50%)',
                    }}
                    style={{left: tooltip.x, top: tooltip.y}}
                />
                <Box
                    sx={{
                        backgroundColor: 'white',
                        border: '1px solid gray',
                        position: 'absolute',
                        transform: 'translate(-50%, -120%)',
                        padding: 2,
                        borderRadius: 2
                    }}
                    style={{left: tooltip.x, top: tooltip.y}}
                >
                    {tooltip.value}
                </Box>
            </>)}
        </DeckGL>
    </>)
}
