import React from 'react'
import { useDispatch } from 'react-redux'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import TextField from '@mui/material/TextField'
import Slider from '@mui/material/Slider'
import Button from '@mui/material/Button'
import ToggleButton from '@mui/material/ToggleButton'
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup'
import IconButton from '@mui/material/IconButton'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'

import { updateImplement, ImplementConfig } from '../commonStores/equipmentState'
import { AppDispatch } from '../store'
import { metersToFeet } from '../utils/guidanceUtils'

interface Props {
    implement: ImplementConfig
    onBack: () => void
}

export function ImplementSettings({ implement, onBack }: Props) {
    const dispatch: AppDispatch = useDispatch()
    const [localImplement, setLocalImplement] = React.useState<ImplementConfig>(implement)

    // Debounce save to database
    const saveTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)

    const handleChange = (updates: Partial<ImplementConfig>) => {
        const updated = { ...localImplement, ...updates }
        setLocalImplement(updated)

        // Debounce database save
        if (saveTimeoutRef.current) {
            clearTimeout(saveTimeoutRef.current)
        }
        saveTimeoutRef.current = setTimeout(() => {
            dispatch(updateImplement(updated))
        }, 300)
    }

    React.useEffect(() => {
        return () => {
            if (saveTimeoutRef.current) {
                clearTimeout(saveTimeoutRef.current)
            }
        }
    }, [])

    // Update local state if implement prop changes (intentionally using id only)
    React.useEffect(() => {
        setLocalImplement(implement)
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [implement.id])

    const handleTypeChange = (_: React.MouseEvent<HTMLElement>, newType: 'pivoting' | 'fixed' | null) => {
        if (newType) {
            handleChange({ type: newType })
        }
    }

    return (
        <Box sx={{ p: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <IconButton onClick={onBack} size="small" sx={{ mr: 1 }}>
                    <ArrowBackIcon />
                </IconButton>
                <Typography variant="subtitle1" fontWeight="bold">
                    Edit Implement
                </Typography>
            </Box>

            {/* Name */}
            <TextField
                fullWidth
                label="Implement Name"
                value={localImplement.name}
                onChange={(e) => handleChange({ name: e.target.value })}
                size="small"
                sx={{ mb: 3 }}
            />

            {/* Type Toggle */}
            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                Hitch Type
            </Typography>
            <ToggleButtonGroup
                value={localImplement.type}
                exclusive
                onChange={handleTypeChange}
                size="small"
                fullWidth
                sx={{ mb: 3 }}
            >
                <ToggleButton value="pivoting">
                    Pivoting
                </ToggleButton>
                <ToggleButton value="fixed">
                    Fixed
                </ToggleButton>
            </ToggleButtonGroup>

            {/* Implement Dimensions */}
            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                Implement Geometry
            </Typography>

            {localImplement.type === 'pivoting' && (
                <Box sx={{ mb: 2 }}>
                    <Typography variant="caption" color="text.secondary">
                        Hitch to Center of Rotation: {localImplement.hitchToCenterRotation.toFixed(2)} m
                    </Typography>
                    <Slider
                        value={localImplement.hitchToCenterRotation}
                        onChange={(_, v) => handleChange({ hitchToCenterRotation: v as number })}
                        min={0}
                        max={10}
                        step={0.1}
                        size="small"
                        marks={[
                            { value: 0, label: '0m' },
                            { value: 10, label: '10m' }
                        ]}
                    />
                </Box>
            )}

            <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary">
                    Hitch to Center of Work: {localImplement.hitchToCenterWork.toFixed(2)} m
                </Typography>
                <Slider
                    value={localImplement.hitchToCenterWork}
                    onChange={(_, v) => handleChange({ hitchToCenterWork: v as number })}
                    min={0}
                    max={15}
                    step={0.1}
                    size="small"
                    marks={[
                        { value: 0, label: '0m' },
                        { value: 15, label: '15m' }
                    ]}
                />
            </Box>

            <Box sx={{ mb: 3 }}>
                <Typography variant="caption" color="text.secondary">
                    Work Width: {localImplement.workWidth.toFixed(2)} m ({metersToFeet(localImplement.workWidth).toFixed(1)} ft)
                </Typography>
                <Slider
                    value={localImplement.workWidth}
                    onChange={(_, v) => handleChange({ workWidth: v as number })}
                    min={1.0}
                    max={30.0}
                    step={0.1}
                    size="small"
                    marks={[
                        { value: 1, label: '1m' },
                        { value: 30, label: '30m' }
                    ]}
                />
            </Box>

            {/* Common Width Presets */}
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
                Common Widths:
            </Typography>
            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap', mb: 3 }}>
                {[
                    { label: '40ft', value: 12.192 },
                    { label: '60ft', value: 18.288 },
                    { label: '90ft', value: 27.432 },
                    { label: '120ft', value: 36.576 }
                ].map(preset => (
                    <Button
                        key={preset.label}
                        size="small"
                        variant={Math.abs(localImplement.workWidth - preset.value) < 0.1 ? 'contained' : 'outlined'}
                        onClick={() => handleChange({ workWidth: preset.value })}
                        sx={{ minWidth: 'auto', px: 1 }}
                    >
                        {preset.label}
                    </Button>
                ))}
            </Box>

            <Button
                variant="outlined"
                size="small"
                onClick={onBack}
                fullWidth
            >
                Done
            </Button>
        </Box>
    )
}
