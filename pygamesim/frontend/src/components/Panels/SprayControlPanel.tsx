import { useState } from 'react';
import { useSimulationStore } from '../../stores/simulationStore';

// Simple circular gauge component
function PressureGauge({ value, max, label }: { value: number; max: number; label: string }) {
  const percentage = (value / max) * 100;
  const rotation = (percentage / 100) * 270 - 135; // -135 to 135 degrees

  return (
    <div className="relative w-24 h-24">
      {/* Gauge background */}
      <svg className="w-full h-full" viewBox="0 0 100 100">
        {/* Background arc */}
        <path
          d="M 15 75 A 40 40 0 1 1 85 75"
          fill="none"
          stroke="#374151"
          strokeWidth="8"
          strokeLinecap="round"
        />
        {/* Value arc */}
        <path
          d="M 15 75 A 40 40 0 1 1 85 75"
          fill="none"
          stroke="#22c55e"
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={`${percentage * 2.2} 220`}
        />
        {/* Needle */}
        <line
          x1="50"
          y1="50"
          x2="50"
          y2="20"
          stroke="#fff"
          strokeWidth="2"
          strokeLinecap="round"
          transform={`rotate(${rotation} 50 50)`}
        />
        {/* Center dot */}
        <circle cx="50" cy="50" r="4" fill="#fff" />
      </svg>

      {/* Value display */}
      <div className="absolute inset-0 flex flex-col items-center justify-center pt-4">
        <span className="text-2xl font-bold">{value}</span>
        <span className="text-xs text-slate-400">{label}</span>
      </div>
    </div>
  );
}

export function SprayControlPanel() {
  const state = useSimulationStore((s) => s.state);
  const toggleImplement = useSimulationStore((s) => s.toggleImplement);

  // Simulated spray state (in real app would come from backend)
  const [pressure] = useState(40);
  const [auxiliaryPressure] = useState(0);
  const [agitationPressure] = useState(23);

  const implementActive = state?.implement.active || false;

  return (
    <div className="absolute left-4 top-1/2 -translate-y-1/2 z-10">
      <div className="panel p-4 w-72 space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs text-blue-400">RightSpot™</div>
            <div className="font-medium flex items-center gap-2">
              <span className="text-lg">💧</span>
              Corn Post Emerge
            </div>
          </div>
          <div className="text-xs text-slate-400">BC</div>
        </div>

        {/* Pressure gauges */}
        <div className="flex justify-between items-center">
          <div className="text-center">
            <div className="text-xs text-slate-400 mb-1">Auxiliary</div>
            <div className="text-lg font-bold">{auxiliaryPressure} <span className="text-xs">PSI</span></div>
          </div>

          <PressureGauge value={pressure} max={100} label="PSI" />

          <div className="text-center">
            <div className="text-xs text-slate-400 mb-1">Agitation</div>
            <div className="text-lg font-bold">{agitationPressure} <span className="text-xs">PSI</span></div>
          </div>
        </div>

        {/* Preset buttons */}
        <div className="flex gap-2">
          <button className="flex-1 px-3 py-2 bg-blue-600 text-white rounded font-medium">
            <div className="text-xs opacity-70">1</div>
            <div>40 <span className="text-xs">PSI</span></div>
          </button>
          <button className="flex-1 px-3 py-2 bg-slate-600 text-white rounded font-medium">
            <div className="text-xs opacity-70">2</div>
            <div>50 <span className="text-xs">PSI</span></div>
          </button>
        </div>

        {/* Divider */}
        <div className="border-t border-slate-600" />

        {/* Control buttons */}
        <div className="space-y-2">
          <button className="w-full px-4 py-3 bg-slate-700 hover:bg-slate-600 text-white rounded-lg font-medium flex items-center gap-3">
            <span className="w-6 h-6 rounded-full border-2 border-slate-400 flex items-center justify-center">
              💧
            </span>
            Prime
          </button>

          <button className="w-full px-4 py-3 bg-slate-700 hover:bg-slate-600 text-white rounded-lg font-medium flex items-center gap-3">
            <span className="w-6 h-6 rounded-full border-2 border-slate-400 flex items-center justify-center">
              ⬇️
            </span>
            Relief
          </button>
        </div>

        {/* Divider */}
        <div className="border-t border-slate-600" />

        {/* Main implement toggle */}
        <button
          onClick={toggleImplement}
          className={`w-full px-4 py-4 rounded-lg font-bold text-lg transition-all ${
            implementActive
              ? 'bg-green-600 hover:bg-green-700 text-white ring-2 ring-green-400 ring-offset-2 ring-offset-slate-800'
              : 'bg-slate-700 hover:bg-slate-600 text-white'
          }`}
        >
          {implementActive ? 'SPRAYING' : 'SPRAY OFF'}
        </button>

        {/* Nozzle info */}
        <div className="flex items-center gap-3 p-3 bg-slate-700/50 rounded-lg">
          <div className="w-8 h-8 bg-slate-600 rounded flex items-center justify-center">
            <span>💨</span>
          </div>
          <div className="flex-1">
            <div className="text-xs text-slate-400">Nozzle</div>
            <div className="font-medium">TTJ60-11008</div>
          </div>
        </div>

        {/* Keyboard shortcut hint */}
        <div className="text-xs text-slate-500 text-center">
          Press SPACE to toggle spray
        </div>
      </div>
    </div>
  );
}
