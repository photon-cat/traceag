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
import Chip from '@mui/material/Chip'
import Alert from '@mui/material/Alert'

import {
    activeABLineSelector,
    activeFieldSelector,
    editModeSelector,
    showSwathsSelector,
    updateABLineSettings,
    setShowSwaths,
    resetABLine
} from '../commonStores/fieldState'
import { SWATH_PRESETS, metersToFeet } from '../utils/guidanceUtils'
import { exportFieldAsIsoxml } from '../utils/exportIsoxml'
import { AppDispatch } from '../store'

export function ABLineSettings() {
    const dispatch: AppDispatch = useDispatch()

    const activeABLine = useSelector(activeABLineSelector)
    const activeField = useSelector(activeFieldSelector)
    const editMode = useSelector(editModeSelector)
    const showSwaths = useSelector(showSwathsSelector)

    if (!activeABLine || !activeField) {
        return null
    }

    const handleSwathPresetChange = (event: SelectChangeEvent<number>) => {
        dispatch(updateABLineSettings({
            abLineId: activeABLine.id,
            swathWidth: event.target.value as number
        }))
    }

    const handleSwathWidthChange = (_event: Event, newValue: number | number[]) => {
        dispatch(updateABLineSettings({
            abLineId: activeABLine.id,
            swathWidth: newValue as number
        }))
    }

    const handleNumSwathsLeftChange = (_event: Event, newValue: number | number[]) => {
        dispatch(updateABLineSettings({
            abLineId: activeABLine.id,
            numSwathsLeft: newValue as number
        }))
    }

    const handleNumSwathsRightChange = (_event: Event, newValue: number | number[]) => {
        dispatch(updateABLineSettings({
            abLineId: activeABLine.id,
            numSwathsRight: newValue as number
        }))
    }

    const handleShowSwathsChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        dispatch(setShowSwaths(event.target.checked))
    }

    const handleNameChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        dispatch(updateABLineSettings({
            abLineId: activeABLine.id,
            name: event.target.value
        }))
    }

    const handleReset = () => {
        dispatch(resetABLine(activeABLine.id))
    }

    const handleExport = async () => {
        try {
            const zipData = await exportFieldAsIsoxml(activeField)

            // Download the file
            const blob = new Blob([zipData], { type: 'application/zip' })
            const url = URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            a.download = `${activeField.name.replace(/\s+/g, '_')}_guidance.zip`
            document.body.appendChild(a)
            a.click()
            document.body.removeChild(a)
            URL.revokeObjectURL(url)
        } catch (error) {
            console.error('Failed to export:', error)
            alert('Failed to export. See console for details.')
        }
    }

    const isComplete = activeABLine.pointA && activeABLine.pointB
    const isSettingPoints = editMode === 'settingA' || editMode === 'settingB'

    return (
        <Box sx={{ p: 2, maxHeight: 400, overflow: 'auto' }}>
            <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                {activeABLine.name}
            </Typography>

            {/* Status */}
            {isSettingPoints && (
                <Alert severity="info" sx={{ mb: 2 }}>
                    {editMode === 'settingA'
                        ? 'Click on the map to set Point A'
                        : 'Click on the map to set Point B'}
                </Alert>
            )}

            {isComplete && (
                <Alert severity="success" sx={{ mb: 2 }}>
                    AB Line complete! Adjust settings below.
                </Alert>
            )}

            {/* Coordinates */}
            {(activeABLine.pointA || activeABLine.pointB) && (
                <Box sx={{ mb: 2, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    {activeABLine.pointA && (
                        <Chip
                            label={`A: ${activeABLine.pointA[1].toFixed(5)}, ${activeABLine.pointA[0].toFixed(5)}`}
                            size="small"
                            color="success"
                            variant="outlined"
                        />
                    )}
                    {activeABLine.pointB && (
                        <Chip
                            label={`B: ${activeABLine.pointB[1].toFixed(5)}, ${activeABLine.pointB[0].toFixed(5)}`}
                            size="small"
                            color="error"
                            variant="outlined"
                        />
                    )}
                </Box>
            )}

            {/* Name */}
            <TextField
                fullWidth
                label="Line Name"
                value={activeABLine.name}
                onChange={handleNameChange}
                size="small"
                sx={{ mb: 2 }}
            />

            {/* Swath Width Preset */}
            <FormControl fullWidth size="small" sx={{ mb: 2 }}>
                <InputLabel>Swath Width</InputLabel>
                <Select
                    value={activeABLine.swathWidth}
                    label="Swath Width"
                    onChange={handleSwathPresetChange}
                >
                    {SWATH_PRESETS.map(preset => (
                        <MenuItem key={preset.value} value={preset.value}>
                            {preset.label}
                        </MenuItem>
                    ))}
                </Select>
            </FormControl>

            {/* Custom Width Slider */}
            <Typography variant="caption" color="text.secondary">
                Width: {metersToFeet(activeABLine.swathWidth).toFixed(1)} ft ({activeABLine.swathWidth.toFixed(1)} m)
            </Typography>
            <Slider
                value={activeABLine.swathWidth}
                onChange={handleSwathWidthChange}
                min={3}
                max={50}
                step={0.1}
                size="small"
                sx={{ mb: 2 }}
            />

            {/* Swaths Left/Right */}
            <Box sx={{ display: 'flex', gap: 2, mb: 2 }}>
                <Box sx={{ flex: 1 }}>
                    <Typography variant="caption" color="text.secondary">
                        Left: {activeABLine.numSwathsLeft}
                    </Typography>
                    <Slider
                        value={activeABLine.numSwathsLeft}
                        onChange={handleNumSwathsLeftChange}
                        min={0}
                        max={20}
                        step={1}
                        size="small"
                    />
                </Box>
                <Box sx={{ flex: 1 }}>
                    <Typography variant="caption" color="text.secondary">
                        Right: {activeABLine.numSwathsRight}
                    </Typography>
                    <Slider
                        value={activeABLine.numSwathsRight}
                        onChange={handleNumSwathsRightChange}
                        min={0}
                        max={20}
                        step={1}
                        size="small"
                    />
                </Box>
            </Box>

            {/* Show Swaths Toggle */}
            <FormControlLabel
                control={
                    <Switch
                        checked={showSwaths}
                        onChange={handleShowSwathsChange}
                        size="small"
                    />
                }
                label="Show Swath Lines"
                sx={{ mb: 2 }}
            />

            {/* Actions */}
            <Box sx={{ display: 'flex', gap: 1 }}>
                <Button
                    variant="outlined"
                    size="small"
                    onClick={handleReset}
                    fullWidth
                >
                    Reset Points
                </Button>
                {isComplete && (
                    <Button
                        variant="contained"
                        size="small"
                        onClick={handleExport}
                        fullWidth
                    >
                        Export Field
                    </Button>
                )}
            </Box>
        </Box>
    )
}
