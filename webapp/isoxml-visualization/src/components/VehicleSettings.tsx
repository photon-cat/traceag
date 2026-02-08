import React from 'react'
import { useDispatch } from 'react-redux'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import TextField from '@mui/material/TextField'
import Slider from '@mui/material/Slider'
import Button from '@mui/material/Button'
import Divider from '@mui/material/Divider'
import IconButton from '@mui/material/IconButton'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'

import { updateVehicle, VehicleConfig } from '../commonStores/equipmentState'
import { AppDispatch } from '../store'

interface Props {
    vehicle: VehicleConfig
    onBack: () => void
}

export function VehicleSettings({ vehicle, onBack }: Props) {
    const dispatch: AppDispatch = useDispatch()
    const [localVehicle, setLocalVehicle] = React.useState<VehicleConfig>(vehicle)

    // Debounce save to database
    const saveTimeoutRef = React.useRef<NodeJS.Timeout | null>(null)

    const handleChange = (updates: Partial<VehicleConfig>) => {
        const updated = { ...localVehicle, ...updates }
        setLocalVehicle(updated)

        // Debounce database save
        if (saveTimeoutRef.current) {
            clearTimeout(saveTimeoutRef.current)
        }
        saveTimeoutRef.current = setTimeout(() => {
            dispatch(updateVehicle(updated))
        }, 300)
    }

    const handleAntennaChange = (updates: Partial<VehicleConfig['antenna']>) => {
        const updated = {
            ...localVehicle,
            antenna: { ...localVehicle.antenna, ...updates }
        }
        setLocalVehicle(updated)

        if (saveTimeoutRef.current) {
            clearTimeout(saveTimeoutRef.current)
        }
        saveTimeoutRef.current = setTimeout(() => {
            dispatch(updateVehicle(updated))
        }, 300)
    }

    React.useEffect(() => {
        return () => {
            if (saveTimeoutRef.current) {
                clearTimeout(saveTimeoutRef.current)
            }
        }
    }, [])

    // Update local state if vehicle prop changes (intentionally using id only)
    React.useEffect(() => {
        setLocalVehicle(vehicle)
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [vehicle.id])

    return (
        <Box sx={{ p: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <IconButton onClick={onBack} size="small" sx={{ mr: 1 }}>
                    <ArrowBackIcon />
                </IconButton>
                <Typography variant="subtitle1" fontWeight="bold">
                    Edit Vehicle
                </Typography>
            </Box>

            {/* Name */}
            <TextField
                fullWidth
                label="Vehicle Name"
                value={localVehicle.name}
                onChange={(e) => handleChange({ name: e.target.value })}
                size="small"
                sx={{ mb: 3 }}
            />

            {/* Vehicle Dimensions */}
            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                Vehicle Dimensions
            </Typography>

            <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary">
                    Wheelbase: {localVehicle.wheelbase.toFixed(2)} m
                </Typography>
                <Slider
                    value={localVehicle.wheelbase}
                    onChange={(_, v) => handleChange({ wheelbase: v as number })}
                    min={1.5}
                    max={4.0}
                    step={0.05}
                    size="small"
                    marks={[
                        { value: 1.5, label: '1.5m' },
                        { value: 4.0, label: '4.0m' }
                    ]}
                />
            </Box>

            <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary">
                    Turning Radius: {localVehicle.turningRadius.toFixed(1)} m
                </Typography>
                <Slider
                    value={localVehicle.turningRadius}
                    onChange={(_, v) => handleChange({ turningRadius: v as number })}
                    min={3.0}
                    max={15.0}
                    step={0.1}
                    size="small"
                    marks={[
                        { value: 3, label: '3m' },
                        { value: 15, label: '15m' }
                    ]}
                />
            </Box>

            <Box sx={{ mb: 3 }}>
                <Typography variant="caption" color="text.secondary">
                    Rear Axle to Hitch: {localVehicle.rearAxleToHitch.toFixed(2)} m
                </Typography>
                <Slider
                    value={localVehicle.rearAxleToHitch}
                    onChange={(_, v) => handleChange({ rearAxleToHitch: v as number })}
                    min={0.5}
                    max={3.0}
                    step={0.05}
                    size="small"
                    marks={[
                        { value: 0.5, label: '0.5m' },
                        { value: 3.0, label: '3.0m' }
                    ]}
                />
            </Box>

            <Divider sx={{ my: 2 }} />

            {/* Antenna Configuration */}
            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                GNSS Antenna Position
            </Typography>

            <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary">
                    Height to Ground: {localVehicle.antenna.heightToGround.toFixed(2)} m
                </Typography>
                <Slider
                    value={localVehicle.antenna.heightToGround}
                    onChange={(_, v) => handleAntennaChange({ heightToGround: v as number })}
                    min={1.0}
                    max={4.0}
                    step={0.05}
                    size="small"
                    marks={[
                        { value: 1.0, label: '1m' },
                        { value: 4.0, label: '4m' }
                    ]}
                />
            </Box>

            <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary">
                    Lateral Offset: {localVehicle.antenna.lateralOffset.toFixed(2)} m
                    ({localVehicle.antenna.lateralOffset < 0 ? 'left' : localVehicle.antenna.lateralOffset > 0 ? 'right' : 'center'})
                </Typography>
                <Slider
                    value={localVehicle.antenna.lateralOffset}
                    onChange={(_, v) => handleAntennaChange({ lateralOffset: v as number })}
                    min={-1.0}
                    max={1.0}
                    step={0.01}
                    size="small"
                    marks={[
                        { value: -1.0, label: '-1m (L)' },
                        { value: 0, label: '0' },
                        { value: 1.0, label: '+1m (R)' }
                    ]}
                />
            </Box>

            <Box sx={{ mb: 3 }}>
                <Typography variant="caption" color="text.secondary">
                    Longitudinal Offset: {localVehicle.antenna.longitudinalOffset.toFixed(2)} m
                    ({localVehicle.antenna.longitudinalOffset > 0 ? 'forward' : localVehicle.antenna.longitudinalOffset < 0 ? 'back' : 'on axle'})
                </Typography>
                <Slider
                    value={localVehicle.antenna.longitudinalOffset}
                    onChange={(_, v) => handleAntennaChange({ longitudinalOffset: v as number })}
                    min={-2.0}
                    max={2.0}
                    step={0.05}
                    size="small"
                    marks={[
                        { value: -2.0, label: '-2m' },
                        { value: 0, label: 'Axle' },
                        { value: 2.0, label: '+2m' }
                    ]}
                />
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
