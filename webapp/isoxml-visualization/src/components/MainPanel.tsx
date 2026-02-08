import React, { useCallback, useState } from 'react'
import { useDispatch, useSelector } from 'react-redux'
import { useDropzone } from 'react-dropzone'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Tabs from '@mui/material/Tabs'
import Tab from '@mui/material/Tab'
import GithubIcon from '@mui/icons-material/GitHub'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import WarningIcon from '@mui/icons-material/Warning'
import DialogContent from '@mui/material/DialogContent'
import FolderOpenIcon from '@mui/icons-material/FolderOpen'
import AgricultureIcon from '@mui/icons-material/Agriculture'
import BuildIcon from '@mui/icons-material/Build'

import { isoxmlFileErrorsSelector, ISOXMLFileState, isoxmlFileStateSelector, isoxmlFileWarningsSelector, loadFile } from '../commonStores/isoxmlFile'
import { AppDispatch } from '../store'
import { ISOXMLFileStructure } from './ISOXMLFileStructure'
import { OperationsPanel } from './OperationsPanel'
import { EquipmentPanel } from './EquipmentPanel'

type TabValue = 'operations' | 'equipment' | 'isoxml'

export function MainPanel() {
    const [openWarnings, setOpenWarnings] = useState(false)
    const [activeTab, setActiveTab] = useState<TabValue>('operations')
    const handleOpenWarnings = () => setOpenWarnings(true)
    const handleCloseWarnings = () => setOpenWarnings(false)

    const dispatch: AppDispatch = useDispatch()
    const onDrop = useCallback(files => {
        dispatch(loadFile(files[0]))
        setActiveTab('isoxml')
    }, [dispatch])
    const {getRootProps, getInputProps, isDragActive, open} = useDropzone({onDrop, noClick: true, noKeyboard: true})
    const fileState = useSelector(isoxmlFileStateSelector)
    const isoxmlWarnings = useSelector(isoxmlFileWarningsSelector)
    const isoxmlErrors = useSelector(isoxmlFileErrorsSelector)

    const handleTabChange = (_event: React.SyntheticEvent, newValue: TabValue) => {
        setActiveTab(newValue)
    }

    const errorMsg = fileState === ISOXMLFileState.ERROR && (
        <>
            <Typography sx={{color: 'red', fontWeight: 'bold', pb: 2}}>
                Error loading ISOXML file
            </Typography>
            {isoxmlErrors.length > 0 && (
                <Typography variant="body2" sx={{textOverflow: 'hidden', color: 'red', pb: 2}}>
                    {isoxmlErrors.join(';')}
                </Typography>
            )}
        </>
    )

    return (
        <Box
            sx={[
                {
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column'
                },
                isDragActive && {
                    background: 'orange',
                    opacity: 0.5
                }
            ]}
            {...getRootProps()}
        >
            <input {...getInputProps()} />

            {/* Tab Header */}
            <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
                <Tabs
                    value={activeTab}
                    onChange={handleTabChange}
                    variant="fullWidth"
                    sx={{ minHeight: 48 }}
                >
                    <Tab
                        icon={<AgricultureIcon />}
                        iconPosition="start"
                        label="Operations"
                        value="operations"
                        sx={{ minHeight: 48, textTransform: 'none' }}
                    />
                    <Tab
                        icon={<BuildIcon />}
                        iconPosition="start"
                        label="Equipment"
                        value="equipment"
                        sx={{ minHeight: 48, textTransform: 'none' }}
                    />
                    <Tab
                        icon={<FolderOpenIcon />}
                        iconPosition="start"
                        label="ISOXML"
                        value="isoxml"
                        sx={{ minHeight: 48, textTransform: 'none' }}
                    />
                </Tabs>
            </Box>

            {/* Tab Content */}
            <Box sx={{ flex: 1, overflow: 'hidden' }}>
                {/* Operations Tab */}
                {activeTab === 'operations' && (
                    <Box sx={{ height: '100%', overflow: 'auto' }}>
                        <OperationsPanel />
                    </Box>
                )}

                {/* Equipment Tab */}
                {activeTab === 'equipment' && (
                    <Box sx={{ height: '100%', overflow: 'auto' }}>
                        <EquipmentPanel />
                    </Box>
                )}

                {/* ISOXML Tab */}
                {activeTab === 'isoxml' && (
                    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                        {/* Not Loaded State */}
                        {(fileState === ISOXMLFileState.NOT_LOADED || fileState === ISOXMLFileState.ERROR) && (
                            <Box
                                sx={{
                                    display: 'flex',
                                    justifyContent: 'center',
                                    flexDirection: 'column',
                                    textAlign: 'center',
                                    flex: 1,
                                    margin: '0 16px'
                                }}
                            >
                                {errorMsg}
                                <Button variant="contained" color="primary" onClick={open}>
                                    Select ISOXML ZIP file
                                </Button>
                                <Typography variant="body2" sx={{ mt: 1, color: 'text.secondary' }}>
                                    or drop it here
                                </Typography>
                            </Box>
                        )}

                        {/* Loading State */}
                        {fileState === ISOXMLFileState.LOADING && (
                            <Box
                                sx={{
                                    display: 'flex',
                                    justifyContent: 'center',
                                    flexDirection: 'column',
                                    textAlign: 'center',
                                    flex: 1,
                                    margin: '0 16px'
                                }}
                            >
                                <Typography variant="h6">Loading ISOXML file...</Typography>
                            </Box>
                        )}

                        {/* Loaded State */}
                        {fileState === ISOXMLFileState.LOADED && (
                            <>
                                <Box sx={{
                                    borderBottom: '1px solid',
                                    borderColor: 'divider',
                                    p: 1,
                                    display: 'flex',
                                    justifyContent: 'center',
                                    alignItems: 'center'
                                }}>
                                    <Button size="small" variant="outlined" onClick={open}>
                                        Open another file
                                    </Button>
                                    {isoxmlWarnings.length > 0 && (
                                        <Button
                                            sx={{ml: 1}}
                                            startIcon={<WarningIcon sx={{color: "orange", mr: -0.75}}/>}
                                            size="small"
                                            color="inherit"
                                            title="Show warnings"
                                            onClick={handleOpenWarnings}
                                        >
                                            {isoxmlWarnings.length}
                                        </Button>
                                    )}
                                </Box>
                                <Box sx={{
                                    flex: '1 1 auto',
                                    overflowY: 'auto',
                                    minHeight: 0
                                }}>
                                    <ISOXMLFileStructure />
                                </Box>
                            </>
                        )}
                    </Box>
                )}
            </Box>

            {/* Footer */}
            <Box sx={{
                borderTop: '1px solid',
                borderColor: 'divider',
                p: 1,
                display: 'flex',
                justifyContent: 'center'
            }}>
                <Button
                    href="https://github.com/aparshin/isoxml-visualization"
                    target="_blank"
                    size="small"
                    startIcon={<GithubIcon />}
                    sx={{ textTransform: 'none' }}
                >
                    GitHub
                </Button>
            </Box>

            {/* Warnings Dialog */}
            <Dialog
                open={openWarnings}
                onClose={handleCloseWarnings}
                fullWidth={true}
                maxWidth="md"
            >
                <DialogTitle>Warnings</DialogTitle>
                <DialogContent>
                    {isoxmlWarnings.map((warning, idx) => (
                        <Box key={idx}>{warning}</Box>
                    ))}
                </DialogContent>
            </Dialog>
        </Box>
    )
}
