import React, { useState } from 'react'
import { useDispatch, useSelector } from 'react-redux'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Button from '@mui/material/Button'
import IconButton from '@mui/material/IconButton'
import TextField from '@mui/material/TextField'
import List from '@mui/material/List'
import ListItem from '@mui/material/ListItem'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemText from '@mui/material/ListItemText'
import ListItemIcon from '@mui/material/ListItemIcon'
import Collapse from '@mui/material/Collapse'
import Divider from '@mui/material/Divider'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Alert from '@mui/material/Alert'
import Chip from '@mui/material/Chip'

import AddIcon from '@mui/icons-material/Add'
import DeleteIcon from '@mui/icons-material/Delete'
import ExpandLess from '@mui/icons-material/ExpandLess'
import ExpandMore from '@mui/icons-material/ExpandMore'
import LandscapeIcon from '@mui/icons-material/Landscape'
import StraightenIcon from '@mui/icons-material/Straighten'
import UndoIcon from '@mui/icons-material/Undo'
import CheckIcon from '@mui/icons-material/Check'
import CloseIcon from '@mui/icons-material/Close'
import EditIcon from '@mui/icons-material/Edit'

import {
    fieldsSelector,
    activeFieldIdSelector,
    activeABLineIdSelector,
    editModeSelector,
    boundaryDrawingPointsSelector,
    createField,
    deleteField,
    setActiveField,
    createABLine,
    deleteABLine,
    setActiveABLine,
    undoBoundaryPoint,
    completeBoundary,
    cancelBoundaryDrawing,
    startEditBoundary,
    Field
} from '../commonStores/fieldState'
import { ABLineSettings } from './ABLineSettings'
import { AppDispatch } from '../store'

export function OperationsPanel() {
    const dispatch: AppDispatch = useDispatch()
    const fields = useSelector(fieldsSelector)
    const activeFieldId = useSelector(activeFieldIdSelector)
    const activeABLineId = useSelector(activeABLineIdSelector)
    const editMode = useSelector(editModeSelector)
    const boundaryDrawingPoints = useSelector(boundaryDrawingPointsSelector)

    const [expandedFields, setExpandedFields] = useState<Set<string>>(new Set())
    const [newFieldDialogOpen, setNewFieldDialogOpen] = useState(false)
    const [newFieldName, setNewFieldName] = useState('')
    const [newABLineDialogOpen, setNewABLineDialogOpen] = useState(false)
    const [newABLineName, setNewABLineName] = useState('')
    const [selectedFieldForABLine, setSelectedFieldForABLine] = useState<string | null>(null)

    const isDrawingBoundary = editMode === 'drawingBoundary'
    const canCompleteBoundary = boundaryDrawingPoints.length >= 3

    const toggleFieldExpanded = (fieldId: string) => {
        setExpandedFields(prev => {
            const newSet = new Set(Array.from(prev))
            if (newSet.has(fieldId)) {
                newSet.delete(fieldId)
            } else {
                newSet.add(fieldId)
            }
            return newSet
        })
    }

    const handleCreateField = () => {
        setNewFieldName('')
        setNewFieldDialogOpen(true)
    }

    const handleConfirmCreateField = () => {
        dispatch(createField({ name: newFieldName || undefined }))
        setNewFieldDialogOpen(false)
    }

    const handleDeleteField = (fieldId: string, e: React.MouseEvent) => {
        e.stopPropagation()
        dispatch(deleteField(fieldId))
    }

    const handleSelectField = (fieldId: string) => {
        dispatch(setActiveField(fieldId))
        setExpandedFields(prev => {
            const arr = Array.from(prev)
            arr.push(fieldId)
            return new Set(arr)
        })
    }

    const handleCreateABLine = (fieldId: string, e: React.MouseEvent) => {
        e.stopPropagation()
        setSelectedFieldForABLine(fieldId)
        setNewABLineName('')
        setNewABLineDialogOpen(true)
    }

    const handleConfirmCreateABLine = () => {
        if (selectedFieldForABLine) {
            dispatch(createABLine({ fieldId: selectedFieldForABLine, name: newABLineName || undefined }))
            dispatch(setActiveField(selectedFieldForABLine))
        }
        setNewABLineDialogOpen(false)
    }

    const handleSelectABLine = (fieldId: string, abLineId: string) => {
        dispatch(setActiveField(fieldId))
        dispatch(setActiveABLine(abLineId))
    }

    const handleDeleteABLine = (fieldId: string, abLineId: string, e: React.MouseEvent) => {
        e.stopPropagation()
        dispatch(deleteABLine({ fieldId, abLineId }))
    }

    const handleUndoBoundaryPoint = () => {
        dispatch(undoBoundaryPoint())
    }

    const handleCompleteBoundary = () => {
        dispatch(completeBoundary())
    }

    const handleCancelBoundary = () => {
        dispatch(cancelBoundaryDrawing())
    }

    const handleEditBoundary = (fieldId: string, e: React.MouseEvent) => {
        e.stopPropagation()
        dispatch(startEditBoundary(fieldId))
    }

    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            {/* Header */}
            <Box sx={{ p: 2, borderBottom: '1px solid', borderColor: 'divider' }}>
                <Typography variant="h6" gutterBottom>
                    Operations
                </Typography>
                {!isDrawingBoundary && (
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={handleCreateField}
                        fullWidth
                        size="small"
                    >
                        New Field
                    </Button>
                )}
            </Box>

            {/* Boundary Drawing Mode UI */}
            {isDrawingBoundary && (
                <Box sx={{ p: 2, bgcolor: 'action.hover' }}>
                    <Alert severity="info" sx={{ mb: 2 }}>
                        Click on the map to draw the field boundary.
                        {boundaryDrawingPoints.length < 3 && (
                            <> Need at least 3 points.</>
                        )}
                    </Alert>

                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                        <Chip
                            label={`${boundaryDrawingPoints.length} points`}
                            size="small"
                            color={canCompleteBoundary ? 'success' : 'default'}
                        />
                    </Box>

                    <Box sx={{ display: 'flex', gap: 1 }}>
                        <Button
                            variant="outlined"
                            size="small"
                            startIcon={<UndoIcon />}
                            onClick={handleUndoBoundaryPoint}
                            disabled={boundaryDrawingPoints.length === 0}
                        >
                            Undo
                        </Button>
                        <Button
                            variant="contained"
                            size="small"
                            color="success"
                            startIcon={<CheckIcon />}
                            onClick={handleCompleteBoundary}
                            disabled={!canCompleteBoundary}
                        >
                            Complete
                        </Button>
                        <Button
                            variant="outlined"
                            size="small"
                            color="error"
                            startIcon={<CloseIcon />}
                            onClick={handleCancelBoundary}
                        >
                            Cancel
                        </Button>
                    </Box>
                </Box>
            )}

            {/* Fields List */}
            <Box sx={{ flex: 1, overflow: 'auto' }}>
                {fields.length === 0 && !isDrawingBoundary ? (
                    <Box sx={{ p: 2, textAlign: 'center', color: 'text.secondary' }}>
                        <LandscapeIcon sx={{ fontSize: 48, mb: 1, opacity: 0.5 }} />
                        <Typography variant="body2">
                            No fields yet. Create a field to get started.
                        </Typography>
                    </Box>
                ) : (
                    <List dense disablePadding>
                        {fields.map((field) => (
                            <FieldListItem
                                key={field.id}
                                field={field}
                                isActive={field.id === activeFieldId}
                                isExpanded={expandedFields.has(field.id)}
                                activeABLineId={activeABLineId}
                                isDrawingBoundary={isDrawingBoundary && field.id === activeFieldId}
                                onToggleExpand={() => toggleFieldExpanded(field.id)}
                                onSelect={() => handleSelectField(field.id)}
                                onDelete={(e) => handleDeleteField(field.id, e)}
                                onCreateABLine={(e) => handleCreateABLine(field.id, e)}
                                onSelectABLine={(abLineId) => handleSelectABLine(field.id, abLineId)}
                                onDeleteABLine={(abLineId, e) => handleDeleteABLine(field.id, abLineId, e)}
                                onEditBoundary={(e) => handleEditBoundary(field.id, e)}
                            />
                        ))}
                    </List>
                )}
            </Box>

            {/* AB Line Settings Panel */}
            {activeABLineId && !isDrawingBoundary && (
                <Box sx={{ borderTop: '1px solid', borderColor: 'divider' }}>
                    <ABLineSettings />
                </Box>
            )}

            {/* Create Field Dialog */}
            <Dialog open={newFieldDialogOpen} onClose={() => setNewFieldDialogOpen(false)}>
                <DialogTitle>Create New Field</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label="Field Name"
                        fullWidth
                        variant="outlined"
                        value={newFieldName}
                        onChange={(e) => setNewFieldName(e.target.value)}
                        placeholder="e.g., North Field"
                    />
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
                        After creating, you'll draw the field boundary on the map.
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setNewFieldDialogOpen(false)}>Cancel</Button>
                    <Button onClick={handleConfirmCreateField} variant="contained">Create & Draw Boundary</Button>
                </DialogActions>
            </Dialog>

            {/* Create AB Line Dialog */}
            <Dialog open={newABLineDialogOpen} onClose={() => setNewABLineDialogOpen(false)}>
                <DialogTitle>Create New AB Line</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label="AB Line Name"
                        fullWidth
                        variant="outlined"
                        value={newABLineName}
                        onChange={(e) => setNewABLineName(e.target.value)}
                        placeholder="e.g., Main Pass"
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setNewABLineDialogOpen(false)}>Cancel</Button>
                    <Button onClick={handleConfirmCreateABLine} variant="contained">Create</Button>
                </DialogActions>
            </Dialog>
        </Box>
    )
}

interface FieldListItemProps {
    field: Field
    isActive: boolean
    isExpanded: boolean
    activeABLineId: string | null
    isDrawingBoundary: boolean
    onToggleExpand: () => void
    onSelect: () => void
    onDelete: (e: React.MouseEvent) => void
    onCreateABLine: (e: React.MouseEvent) => void
    onSelectABLine: (abLineId: string) => void
    onDeleteABLine: (abLineId: string, e: React.MouseEvent) => void
    onEditBoundary: (e: React.MouseEvent) => void
}

function FieldListItem({
    field,
    isActive,
    isExpanded,
    activeABLineId,
    isDrawingBoundary,
    onToggleExpand,
    onSelect,
    onDelete,
    onCreateABLine,
    onSelectABLine,
    onDeleteABLine,
    onEditBoundary
}: FieldListItemProps) {
    const hasBoundary = field.boundary && field.boundary.length >= 3

    return (
        <>
            <ListItem
                disablePadding
                secondaryAction={
                    !isDrawingBoundary && (
                        <Box sx={{ display: 'flex', gap: 0.5 }}>
                            {hasBoundary && (
                                <IconButton
                                    edge="end"
                                    size="small"
                                    onClick={onCreateABLine}
                                    title="Add AB Line"
                                >
                                    <AddIcon fontSize="small" />
                                </IconButton>
                            )}
                            <IconButton
                                edge="end"
                                size="small"
                                onClick={onEditBoundary}
                                title="Edit Boundary"
                            >
                                <EditIcon fontSize="small" />
                            </IconButton>
                            <IconButton
                                edge="end"
                                size="small"
                                onClick={onDelete}
                                title="Delete Field"
                            >
                                <DeleteIcon fontSize="small" />
                            </IconButton>
                        </Box>
                    )
                }
            >
                <ListItemButton
                    selected={isActive}
                    onClick={onSelect}
                    sx={{ pr: hasBoundary ? 14 : 10 }}
                    disabled={isDrawingBoundary && !isActive}
                >
                    <ListItemIcon sx={{ minWidth: 36 }}>
                        <IconButton
                            size="small"
                            onClick={(e) => { e.stopPropagation(); onToggleExpand(); }}
                            disabled={!hasBoundary}
                        >
                            {isExpanded ? <ExpandLess /> : <ExpandMore />}
                        </IconButton>
                    </ListItemIcon>
                    <ListItemIcon sx={{ minWidth: 36 }}>
                        <LandscapeIcon color={isActive ? 'primary' : 'inherit'} />
                    </ListItemIcon>
                    <ListItemText
                        primary={field.name}
                        secondary={
                            !hasBoundary
                                ? 'Drawing boundary...'
                                : `${field.abLines.length} AB line${field.abLines.length !== 1 ? 's' : ''}`
                        }
                        secondaryTypographyProps={{
                            color: !hasBoundary ? 'warning.main' : 'text.secondary'
                        }}
                    />
                </ListItemButton>
            </ListItem>

            <Collapse in={isExpanded && hasBoundary} timeout="auto" unmountOnExit>
                <List component="div" disablePadding dense>
                    {field.abLines.length === 0 ? (
                        <ListItem sx={{ pl: 8 }}>
                            <ListItemText
                                secondary="No AB lines. Click + to add one."
                                secondaryTypographyProps={{ variant: 'caption' }}
                            />
                        </ListItem>
                    ) : (
                        field.abLines.map((abLine) => (
                            <ListItem
                                key={abLine.id}
                                disablePadding
                                secondaryAction={
                                    <IconButton
                                        edge="end"
                                        size="small"
                                        onClick={(e) => onDeleteABLine(abLine.id, e)}
                                        title="Delete AB Line"
                                    >
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                }
                            >
                                <ListItemButton
                                    selected={abLine.id === activeABLineId}
                                    onClick={() => onSelectABLine(abLine.id)}
                                    sx={{ pl: 8, pr: 6 }}
                                >
                                    <ListItemIcon sx={{ minWidth: 36 }}>
                                        <StraightenIcon
                                            fontSize="small"
                                            color={abLine.id === activeABLineId ? 'primary' : 'inherit'}
                                        />
                                    </ListItemIcon>
                                    <ListItemText
                                        primary={abLine.name}
                                        secondary={
                                            abLine.pointA && abLine.pointB
                                                ? 'Complete'
                                                : abLine.pointA
                                                    ? 'Set point B'
                                                    : 'Set point A'
                                        }
                                        secondaryTypographyProps={{
                                            color: abLine.pointA && abLine.pointB ? 'success.main' : 'warning.main'
                                        }}
                                    />
                                </ListItemButton>
                            </ListItem>
                        ))
                    )}
                </List>
            </Collapse>
            <Divider />
        </>
    )
}
