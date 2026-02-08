import React from 'react'
import { useDispatch, useSelector } from 'react-redux'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import TextField from '@mui/material/TextField'
import FormControl from '@mui/material/FormControl'
import InputLabel from '@mui/material/InputLabel'
import Select, { SelectChangeEvent } from '@mui/material/Select'
import MenuItem from '@mui/material/MenuItem'
import FormControlLabel from '@mui/material/FormControlLabel'
import Switch from '@mui/material/Switch'
import Button from '@mui/material/Button'
import Slider from '@mui/material/Slider'
import Divider from '@mui/material/Divider'

import {
    guidanceModeSelector,
    guidanceSwathWidthSelector,
    guidanceNumSwathsLeftSelector,
    guidanceNumSwathsRightSelector,
    guidanceShowSwathsSelector,
    guidanceLineNameSelector,
    guidancePointASelector,
    guidancePointBSelector,
    setSwathWidth,
    setNumSwathsLeft,
    setNumSwathsRight,
    setShowSwaths,
    setLineName,
    resetGuidance,
    cancelGuidance
} from '../commonStores/guidanceState'
import { SWATH_PRESETS, metersToFeet } from '../utils/guidanceUtils'
import { exportGuidanceAsIsoxml } from '../utils/exportIsoxml'
import { AppDispatch } from '../store'

export function GuidancePanel() {
    const dispatch: AppDispatch = useDispatch()

    const mode = useSelector(guidanceModeSelector)
    const swathWidth = useSelector(guidanceSwathWidthSelector)
    const numSwathsLeft = useSelector(guidanceNumSwathsLeftSelector)
    const numSwathsRight = useSelector(guidanceNumSwathsRightSelector)
    const showSwaths = useSelector(guidanceShowSwathsSelector)
    const lineName = useSelector(guidanceLineNameSelector)
    const pointA = useSelector(guidancePointASelector)
    const pointB = useSelector(guidancePointBSelector)

    const handleSwathPresetChange = (event: SelectChangeEvent<number>) => {
        dispatch(setSwathWidth(event.target.value as number))
    }

    const handleSwathWidthChange = (_event: Event, newValue: number | number[]) => {
        dispatch(setSwathWidth(newValue as number))
    }

    const handleNumSwathsLeftChange = (_event: Event, newValue: number | number[]) => {
        dispatch(setNumSwathsLeft(newValue as number))
    }

    const handleNumSwathsRightChange = (_event: Event, newValue: number | number[]) => {
        dispatch(setNumSwathsRight(newValue as number))
    }

    const handleShowSwathsChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        dispatch(setShowSwaths(event.target.checked))
    }

    const handleLineNameChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        dispatch(setLineName(event.target.value))
    }

    const handleReset = () => {
        dispatch(resetGuidance())
    }

    const handleCancel = () => {
        dispatch(cancelGuidance())
    }

    const handleExport = async () => {
        if (pointA && pointB) {
            try {
                const zipData = await exportGuidanceAsIsoxml(
                    pointA,
                    pointB,
                    lineName,
                    swathWidth,
                    numSwathsLeft,
                    numSwathsRight
                )

                // Download the file
                const blob = new Blob([zipData], { type: 'application/zip' })
                const url = URL.createObjectURL(blob)
                const a = document.createElement('a')
                a.href = url
                a.download = `${lineName.replace(/\s+/g, '_')}_guidance.zip`
                document.body.appendChild(a)
                a.click()
                document.body.removeChild(a)
                URL.revokeObjectURL(url)
            } catch (error) {
                console.error('Failed to export guidance:', error)
                alert('Failed to export guidance. See console for details.')
            }
        }
    }

    const isComplete = mode === 'complete'

    return (
        <Box sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
                AB Line Guidance
            </Typography>

            {/* Status message */}
            <Box sx={{ mb: 2, p: 1, bgcolor: 'action.hover', borderRadius: 1 }}>
                {mode === 'settingA' && (
                    <Typography color="primary">Click on map to set Point A</Typography>
                )}
                {mode === 'settingB' && (
                    <Typography color="primary">Click on map to set Point B</Typography>
                )}
                {mode === 'complete' && (
                    <Typography color="success.main">AB Line set! Adjust settings below.</Typography>
                )}
            </Box>

            {/* Line name */}
            <TextField
                fullWidth
                label="Line Name"
                value={lineName}
                onChange={handleLineNameChange}
                size="small"
                sx={{ mb: 2 }}
            />

            <Divider sx={{ my: 2 }} />

            {/* Swath width preset selector */}
            <FormControl fullWidth size="small" sx={{ mb: 2 }}>
                <InputLabel>Swath Width Preset</InputLabel>
                <Select
                    value={swathWidth}
                    label="Swath Width Preset"
                    onChange={handleSwathPresetChange}
                >
                    {SWATH_PRESETS.map(preset => (
                        <MenuItem key={preset.value} value={preset.value}>
                            {preset.label}
                        </MenuItem>
                    ))}
                </Select>
            </FormControl>

            {/* Custom swath width slider */}
            <Typography gutterBottom>
                Swath Width: {metersToFeet(swathWidth).toFixed(1)} ft ({swathWidth.toFixed(1)} m)
            </Typography>
            <Slider
                value={swathWidth}
                onChange={handleSwathWidthChange}
                min={3}
                max={50}
                step={0.1}
                sx={{ mb: 2 }}
            />

            <Divider sx={{ my: 2 }} />

            {/* Number of swaths */}
            <Typography gutterBottom>
                Swaths Left: {numSwathsLeft}
            </Typography>
            <Slider
                value={numSwathsLeft}
                onChange={handleNumSwathsLeftChange}
                min={0}
                max={20}
                step={1}
                marks
                sx={{ mb: 2 }}
            />

            <Typography gutterBottom>
                Swaths Right: {numSwathsRight}
            </Typography>
            <Slider
                value={numSwathsRight}
                onChange={handleNumSwathsRightChange}
                min={0}
                max={20}
                step={1}
                marks
                sx={{ mb: 2 }}
            />

            {/* Show swaths toggle */}
            <FormControlLabel
                control={
                    <Switch
                        checked={showSwaths}
                        onChange={handleShowSwathsChange}
                    />
                }
                label="Show Swath Lines"
                sx={{ mb: 2 }}
            />

            <Divider sx={{ my: 2 }} />

            {/* Action buttons */}
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                {isComplete && (
                    <Button
                        variant="contained"
                        color="primary"
                        onClick={handleExport}
                        fullWidth
                    >
                        Export Guidance ISOXML
                    </Button>
                )}

                <Button
                    variant="outlined"
                    color="secondary"
                    onClick={handleReset}
                    fullWidth
                >
                    Reset Line
                </Button>

                <Button
                    variant="outlined"
                    color="error"
                    onClick={handleCancel}
                    fullWidth
                >
                    Cancel
                </Button>
            </Box>

            {/* Coordinates display */}
            {(pointA || pointB) && (
                <Box sx={{ mt: 2, p: 1, bgcolor: 'grey.100', borderRadius: 1, fontSize: '0.75rem' }}>
                    {pointA && (
                        <Typography variant="caption" display="block">
                            A: {pointA[1].toFixed(6)}, {pointA[0].toFixed(6)}
                        </Typography>
                    )}
                    {pointB && (
                        <Typography variant="caption" display="block">
                            B: {pointB[1].toFixed(6)}, {pointB[0].toFixed(6)}
                        </Typography>
                    )}
                </Box>
            )}
        </Box>
    )
}
