import { useEffect } from 'react';
import { Field3D } from './components/Field3D';
import { TopBar } from './components/HUD';
import { SprayControlPanel, GuidancePanel, BottomBar, TaskPanel } from './components/Panels';
import { useWebSocket } from './hooks/useWebSocket';
import { useKeyboardControls } from './hooks/useKeyboardControls';
import { useSimulationStore } from './stores/simulationStore';

function LoadingScreen() {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-slate-900">
      <div className="text-center">
        <div className="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
        <div className="text-xl text-slate-300">Connecting to simulation...</div>
        <div className="text-sm text-slate-500 mt-2">Make sure the Python server is running</div>
        <div className="text-xs text-slate-600 mt-4 font-mono">
          python -m pygamesim.web.server
        </div>
      </div>
    </div>
  );
}

function App() {
  useWebSocket();
  useKeyboardControls();

  const connected = useSimulationStore((s) => s.connected);
  const state = useSimulationStore((s) => s.state);

  // Request coverage updates periodically
  useEffect(() => {
    if (!connected) return;

    const interval = setInterval(() => {
      const ws = useSimulationStore.getState().ws;
      const coverageCount = useSimulationStore.getState().coverage.length;

      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: 'getCoverage',
          lastIndex: coverageCount,
        }));
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [connected]);

  if (!connected || !state) {
    return <LoadingScreen />;
  }

  return (
    <div className="relative w-full h-full overflow-hidden">
      {/* 3D Field View */}
      <Field3D />

      {/* HUD Overlay */}
      <TopBar />

      {/* Side Panels */}
      <TaskPanel />
      <SprayControlPanel />
      <GuidancePanel />

      {/* Bottom Bar */}
      <BottomBar />
    </div>
  );
}

export default App;
