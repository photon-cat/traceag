import { useSimulationStore } from '../../stores/simulationStore';
import { GuidanceBar } from './GuidanceBar';

export function TopBar() {
  const state = useSimulationStore((s) => s.state);
  const connected = useSimulationStore((s) => s.connected);
  const coverage = useSimulationStore((s) => s.coverage);

  // Calculate area covered (rough estimate)
  const areaCovered = coverage.length * 0.3 * (state?.implement.width || 6) / 10000; // hectares

  // Format time
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}'${secs.toString().padStart(2, '0')}"`;
  };

  // Convert m/s to mph
  const speedMph = (state?.localizer.speed || 0) * 2.237;

  return (
    <div className="absolute top-0 left-0 right-0 z-10 p-4">
      <div className="flex items-start justify-between gap-4">
        {/* Left: Speed and Area */}
        <div className="panel p-3 flex items-center gap-6">
          {/* Connection status */}
          <div className={`w-3 h-3 rounded-full ${connected ? 'bg-green-500' : 'bg-red-500'}`} />

          {/* Area */}
          <div className="text-center">
            <div className="text-2xl font-bold tabular-nums">
              {areaCovered.toFixed(2)}
              <span className="text-sm text-slate-400 ml-1">ac</span>
            </div>
          </div>

          {/* Speed */}
          <div className="text-center">
            <div className="text-4xl font-bold tabular-nums">
              {speedMph.toFixed(0)}
              <span className="text-lg text-slate-400 ml-1">mph</span>
            </div>
          </div>
        </div>

        {/* Center: Time and Guidance Bar */}
        <div className="flex flex-col items-center gap-2">
          {/* Time */}
          <div className="panel px-4 py-1">
            <span className="text-xl font-mono tabular-nums">
              {formatTime(state?.timestamp || 0)}
            </span>
          </div>

          {/* Guidance Bar */}
          <div className="panel p-3">
            <GuidanceBar />
          </div>
        </div>

        {/* Right: Status icons */}
        <div className="panel p-3 flex items-center gap-4">
          {/* GPS Status */}
          <div className="flex flex-col items-center">
            <svg className="w-6 h-6 text-green-400" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
            </svg>
            <span className="text-xs text-slate-400">RTK</span>
          </div>

          {/* Signal strength */}
          <div className="flex items-end gap-0.5 h-6">
            {[1, 2, 3, 4, 5].map((i) => (
              <div
                key={i}
                className={`w-1 bg-green-400 rounded-sm`}
                style={{ height: `${i * 4 + 4}px` }}
              />
            ))}
          </div>

          {/* Settings */}
          <button className="p-1 hover:bg-slate-600 rounded">
            <svg className="w-6 h-6 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}
