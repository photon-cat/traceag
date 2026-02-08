import React, { useEffect } from 'react'
import { useDispatch } from 'react-redux'
import { createTheme, ThemeProvider } from '@mui/material/styles';
import { MainPanel } from './components/MainPanel';
import { Map } from './components/Map';
import CssBaseline from '@mui/material/CssBaseline';
import Box from '@mui/material/Box';
import { initializeEquipment } from './commonStores/equipmentState';
import { initializeFields } from './commonStores/fieldState';
import { AppDispatch } from './store';

const theme = createTheme({
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        html: {
            height: '100%'
        },
        body: {
            height: '100%',
            margin: 0
        },
        '#root': {
            height: '100%'
        }
      }
    }
  }
})

function App() {
    const dispatch: AppDispatch = useDispatch()

    // Initialize database on app startup
    useEffect(() => {
        dispatch(initializeEquipment())
        dispatch(initializeFields())
    }, [dispatch])

    return (
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <Box sx={{ width: '100%', height: '100%', display: 'flex' }}>
                <Box sx={{
                    width: '300px',
                    borderRight: '1px solid gray'
                }}>
                    <MainPanel />
                </Box>
                <Box sx={{ flexGrow: 1, position: 'relative', margin: '1px' }}>
                    <Map />
                </Box>
            </Box>
        </ThemeProvider>
    )
}

export default App
