import React, { useEffect } from 'react'
import { useDispatch, useSelector } from 'react-redux'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Tabs from '@mui/material/Tabs'
import Tab from '@mui/material/Tab'
import List from '@mui/material/List'
import ListItem from '@mui/material/ListItem'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemText from '@mui/material/ListItemText'
import ListItemIcon from '@mui/material/ListItemIcon'
import IconButton from '@mui/material/IconButton'
import Button from '@mui/material/Button'
import Chip from '@mui/material/Chip'
import CircularProgress from '@mui/material/CircularProgress'
import Alert from '@mui/material/Alert'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import TextField from '@mui/material/TextField'
import AddIcon from '@mui/icons-material/Add'
import DeleteIcon from '@mui/icons-material/Delete'
import AgricultureIcon from '@mui/icons-material/Agriculture'
import DirectionsCarIcon from '@mui/icons-material/DirectionsCar'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'

import {
    initializeEquipment,
    vehiclesSelector,
    implementsSelector,
    activeVehicleIdSelector,
    activeImplementIdSelector,
    isEquipmentLoadingSelector,
    isEquipmentInitializedSelector,
    equipmentErrorSelector,
    setActiveVehicle,
    setActiveImplement,
    createVehicle,
    createImplement,
    removeVehicle,
    removeImplement,
    VehicleConfig,
    ImplementConfig
} from '../commonStores/equipmentState'
import { AppDispatch } from '../store'
import { VehicleSettings } from './VehicleSettings'
import { ImplementSettings } from './ImplementSettings'

interface TabPanelProps {
    children?: React.ReactNode
    index: number
    value: number
}

function TabPanel({ children, value, index }: TabPanelProps) {
    return (
        <div role="tabpanel" hidden={value !== index}>
            {value === index && <Box>{children}</Box>}
        </div>
    )
}

export function EquipmentPanel() {
    const dispatch: AppDispatch = useDispatch()

    const vehicles = useSelector(vehiclesSelector)
    const implements_ = useSelector(implementsSelector)
    const activeVehicleId = useSelector(activeVehicleIdSelector)
    const activeImplementId = useSelector(activeImplementIdSelector)
    const isLoading = useSelector(isEquipmentLoadingSelector)
    const isInitialized = useSelector(isEquipmentInitializedSelector)
    const error = useSelector(equipmentErrorSelector)

    const [tabValue, setTabValue] = React.useState(0)
    const [editingVehicle, setEditingVehicle] = React.useState<VehicleConfig | null>(null)
    const [editingImplement, setEditingImplement] = React.useState<ImplementConfig | null>(null)
    const [newVehicleDialogOpen, setNewVehicleDialogOpen] = React.useState(false)
    const [newImplementDialogOpen, setNewImplementDialogOpen] = React.useState(false)
    const [newName, setNewName] = React.useState('')
    const [deleteConfirmOpen, setDeleteConfirmOpen] = React.useState(false)
    const [itemToDelete, setItemToDelete] = React.useState<{ type: 'vehicle' | 'implement'; id: string; name: string } | null>(null)

    // Initialize equipment database on mount
    useEffect(() => {
        if (!isInitialized && !isLoading) {
            dispatch(initializeEquipment())
        }
    }, [dispatch, isInitialized, isLoading])

    const handleTabChange = (_: React.SyntheticEvent, newValue: number) => {
        setTabValue(newValue)
        setEditingVehicle(null)
        setEditingImplement(null)
    }

    const handleVehicleClick = (vehicle: VehicleConfig) => {
        setEditingVehicle(vehicle)
    }

    const handleImplementClick = (implement: ImplementConfig) => {
        setEditingImplement(implement)
    }

    const handleSetActiveVehicle = (id: string) => {
        dispatch(setActiveVehicle(id))
    }

    const handleSetActiveImplement = (id: string) => {
        dispatch(setActiveImplement(id))
    }

    const handleCreateVehicle = () => {
        if (!newName.trim()) return
        dispatch(createVehicle({
            name: newName.trim(),
            wheelbase: 2.5,
            turningRadius: 5.0,
            rearAxleToHitch: 1.5,
            antenna: { heightToGround: 2.5, lateralOffset: 0, longitudinalOffset: 1.0 }
        }))
        setNewName('')
        setNewVehicleDialogOpen(false)
    }

    const handleCreateImplement = () => {
        if (!newName.trim()) return
        dispatch(createImplement({
            name: newName.trim(),
            type: 'pivoting',
            hitchToCenterRotation: 2.0,
            hitchToCenterWork: 5.0,
            workWidth: 12.192
        }))
        setNewName('')
        setNewImplementDialogOpen(false)
    }

    const handleDeleteClick = (type: 'vehicle' | 'implement', id: string, name: string) => {
        setItemToDelete({ type, id, name })
        setDeleteConfirmOpen(true)
    }

    const handleConfirmDelete = () => {
        if (!itemToDelete) return
        if (itemToDelete.type === 'vehicle') {
            dispatch(removeVehicle({ id: itemToDelete.id, vehicles, activeVehicleId }))
        } else {
            dispatch(removeImplement({ id: itemToDelete.id, implements_: implements_, activeImplementId }))
        }
        setDeleteConfirmOpen(false)
        setItemToDelete(null)
    }

    if (isLoading) {
        return (
            <Box sx={{ p: 2, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                <CircularProgress size={24} sx={{ mr: 1 }} />
                <Typography>Loading equipment...</Typography>
            </Box>
        )
    }

    if (error) {
        return (
            <Box sx={{ p: 2 }}>
                <Alert severity="error">{error}</Alert>
            </Box>
        )
    }

    // Show vehicle settings if editing
    if (editingVehicle) {
        return (
            <VehicleSettings
                vehicle={editingVehicle}
                onBack={() => setEditingVehicle(null)}
            />
        )
    }

    // Show implement settings if editing
    if (editingImplement) {
        return (
            <ImplementSettings
                implement={editingImplement}
                onBack={() => setEditingImplement(null)}
            />
        )
    }

    return (
        <Box sx={{ width: '100%' }}>
            <Tabs value={tabValue} onChange={handleTabChange} variant="fullWidth">
                <Tab label="Vehicles" icon={<DirectionsCarIcon />} iconPosition="start" sx={{ minHeight: 48 }} />
                <Tab label="Implements" icon={<AgricultureIcon />} iconPosition="start" sx={{ minHeight: 48 }} />
            </Tabs>

            {/* Vehicles Tab */}
            <TabPanel value={tabValue} index={0}>
                <List dense>
                    {vehicles.map((vehicle) => (
                        <ListItem
                            key={vehicle.id}
                            disablePadding
                            secondaryAction={
                                <Box>
                                    {activeVehicleId !== vehicle.id && (
                                        <IconButton
                                            size="small"
                                            onClick={(e) => {
                                                e.stopPropagation()
                                                handleDeleteClick('vehicle', vehicle.id, vehicle.name)
                                            }}
                                        >
                                            <DeleteIcon fontSize="small" />
                                        </IconButton>
                                    )}
                                </Box>
                            }
                        >
                            <ListItemButton onClick={() => handleVehicleClick(vehicle)}>
                                <ListItemIcon sx={{ minWidth: 36 }}>
                                    {activeVehicleId === vehicle.id ? (
                                        <CheckCircleIcon color="success" />
                                    ) : (
                                        <DirectionsCarIcon color="disabled" />
                                    )}
                                </ListItemIcon>
                                <ListItemText
                                    primary={vehicle.name}
                                    secondary={`WB: ${vehicle.wheelbase}m, Turn: ${vehicle.turningRadius}m`}
                                />
                                {activeVehicleId !== vehicle.id && (
                                    <Button
                                        size="small"
                                        variant="outlined"
                                        onClick={(e) => {
                                            e.stopPropagation()
                                            handleSetActiveVehicle(vehicle.id)
                                        }}
                                        sx={{ mr: 1 }}
                                    >
                                        Use
                                    </Button>
                                )}
                                {activeVehicleId === vehicle.id && (
                                    <Chip label="Active" size="small" color="success" sx={{ mr: 1 }} />
                                )}
                            </ListItemButton>
                        </ListItem>
                    ))}
                </List>
                <Box sx={{ p: 2, pt: 0 }}>
                    <Button
                        fullWidth
                        variant="outlined"
                        startIcon={<AddIcon />}
                        onClick={() => {
                            setNewName('')
                            setNewVehicleDialogOpen(true)
                        }}
                    >
                        Add Vehicle
                    </Button>
                </Box>
            </TabPanel>

            {/* Implements Tab */}
            <TabPanel value={tabValue} index={1}>
                <List dense>
                    {implements_.map((implement) => (
                        <ListItem
                            key={implement.id}
                            disablePadding
                            secondaryAction={
                                <Box>
                                    {activeImplementId !== implement.id && (
                                        <IconButton
                                            size="small"
                                            onClick={(e) => {
                                                e.stopPropagation()
                                                handleDeleteClick('implement', implement.id, implement.name)
                                            }}
                                        >
                                            <DeleteIcon fontSize="small" />
                                        </IconButton>
                                    )}
                                </Box>
                            }
                        >
                            <ListItemButton onClick={() => handleImplementClick(implement)}>
                                <ListItemIcon sx={{ minWidth: 36 }}>
                                    {activeImplementId === implement.id ? (
                                        <CheckCircleIcon color="success" />
                                    ) : (
                                        <AgricultureIcon color="disabled" />
                                    )}
                                </ListItemIcon>
                                <ListItemText
                                    primary={implement.name}
                                    secondary={`${implement.type}, Width: ${implement.workWidth.toFixed(1)}m`}
                                />
                                {activeImplementId !== implement.id && (
                                    <Button
                                        size="small"
                                        variant="outlined"
                                        onClick={(e) => {
                                            e.stopPropagation()
                                            handleSetActiveImplement(implement.id)
                                        }}
                                        sx={{ mr: 1 }}
                                    >
                                        Use
                                    </Button>
                                )}
                                {activeImplementId === implement.id && (
                                    <Chip label="Active" size="small" color="success" sx={{ mr: 1 }} />
                                )}
                            </ListItemButton>
                        </ListItem>
                    ))}
                </List>
                <Box sx={{ p: 2, pt: 0 }}>
                    <Button
                        fullWidth
                        variant="outlined"
                        startIcon={<AddIcon />}
                        onClick={() => {
                            setNewName('')
                            setNewImplementDialogOpen(true)
                        }}
                    >
                        Add Implement
                    </Button>
                </Box>
            </TabPanel>

            {/* New Vehicle Dialog */}
            <Dialog open={newVehicleDialogOpen} onClose={() => setNewVehicleDialogOpen(false)}>
                <DialogTitle>New Vehicle</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label="Vehicle Name"
                        fullWidth
                        value={newName}
                        onChange={(e) => setNewName(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') handleCreateVehicle()
                        }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setNewVehicleDialogOpen(false)}>Cancel</Button>
                    <Button onClick={handleCreateVehicle} variant="contained" disabled={!newName.trim()}>
                        Create
                    </Button>
                </DialogActions>
            </Dialog>

            {/* New Implement Dialog */}
            <Dialog open={newImplementDialogOpen} onClose={() => setNewImplementDialogOpen(false)}>
                <DialogTitle>New Implement</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label="Implement Name"
                        fullWidth
                        value={newName}
                        onChange={(e) => setNewName(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') handleCreateImplement()
                        }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setNewImplementDialogOpen(false)}>Cancel</Button>
                    <Button onClick={handleCreateImplement} variant="contained" disabled={!newName.trim()}>
                        Create
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Delete Confirmation Dialog */}
            <Dialog open={deleteConfirmOpen} onClose={() => setDeleteConfirmOpen(false)}>
                <DialogTitle>Delete {itemToDelete?.type === 'vehicle' ? 'Vehicle' : 'Implement'}?</DialogTitle>
                <DialogContent>
                    <Typography>
                        Are you sure you want to delete "{itemToDelete?.name}"?
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDeleteConfirmOpen(false)}>Cancel</Button>
                    <Button onClick={handleConfirmDelete} color="error" variant="contained">
                        Delete
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    )
}
