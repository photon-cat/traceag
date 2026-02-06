import { useSimulationStore } from '../../stores/simulationStore';

export function GuidancePanel() {
  const state = useSimulationStore((s) => s.state);
  const setAPoint = useSimulationStore((s) => s.setAPoint);
  const setBPoint = useSimulationStore((s) => s.setBPoint);
  const clearGuidance = useSimulationStore((s) => s.clearGuidance);
  const reset = useSimulationStore((s) => s.reset);

  const hasABLine = !!state?.guidance.abLine;
  const lineIndex = state?.guidance.activeLineIndex || 0;
  const xte = state?.guidance.crossTrackError || 0;
  const swathWidth = state?.guidance.swathWidth || 6;

  // Convert XTE to inches for display
  const xteInches = Math.abs(xte * 39.37);

  return (
    <div className="absolute right-4 top-1/2 -translate-y-1/2 z-10">
      <div className="panel p-4 w-64 space-y-4">
        {/* Header with close button */}
        <div className="flex items-center justify-between">
          <button
            onClick={clearGuidance}
            className="p-2 hover:bg-slate-600 rounded"
            title="Clear guidance"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
          <div className="text-right">
            <div className="font-medium">AB Line</div>
            <div className="text-sm text-slate-400">
              Pass {Math.abs(lineIndex) + 1} {lineIndex >= 0 ? 'R' : 'L'}
            </div>
          </div>
        </div>

        {/* AB Point buttons */}
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={setAPoint}
            className={`px-4 py-3 rounded-lg font-medium transition-colors ${
              hasABLine
                ? 'bg-green-600/30 border border-green-500 text-green-400'
                : 'bg-blue-600 hover:bg-blue-700 text-white'
            }`}
          >
            <div className="text-xs opacity-70">Set</div>
            <div className="text-lg">A Point</div>
          </button>
          <button
            onClick={setBPoint}
            className={`px-4 py-3 rounded-lg font-medium transition-colors ${
              hasABLine
                ? 'bg-green-600/30 border border-green-500 text-green-400'
                : 'bg-slate-600 hover:bg-slate-500 text-white'
            }`}
          >
            <div className="text-xs opacity-70">Set</div>
            <div className="text-lg">B Point</div>
          </button>
        </div>

        {/* Navigation arrows */}
        <div className="flex items-center justify-center gap-2">
          <button className="p-3 bg-slate-700 hover:bg-slate-600 rounded-lg">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <button className="p-3 bg-slate-700 hover:bg-slate-600 rounded-lg">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
          <button className="p-3 bg-slate-700 hover:bg-slate-600 rounded-lg">
            <svg className="w-5 h-5 rotate-180" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
          <button className="p-3 bg-slate-700 hover:bg-slate-600 rounded-lg">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        {/* Divider */}
        <div className="border-t border-slate-600" />

        {/* Nudge controls */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm text-slate-400">Nudge</span>
            <span className="font-mono">{xteInches.toFixed(1)} in</span>
          </div>

          <div className="flex items-center gap-2">
            <button className="flex-1 px-3 py-2 bg-slate-700 hover:bg-slate-600 rounded text-lg">
              ←
            </button>
            <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-full">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </button>
            <button className="flex-1 px-3 py-2 bg-slate-700 hover:bg-slate-600 rounded text-lg">
              →
            </button>
          </div>
        </div>

        {/* Swath width display */}
        <div className="grid grid-cols-2 gap-4 text-center">
          <div className="p-2 bg-slate-700/50 rounded">
            <div className="text-2xl font-bold">{(swathWidth * 3.281).toFixed(1)}</div>
            <div className="text-xs text-slate-400">ft width</div>
          </div>
          <div className="p-2 bg-slate-700/50 rounded">
            <div className="text-2xl font-bold">{(swathWidth * 39.37).toFixed(0)}</div>
            <div className="text-xs text-slate-400">in width</div>
          </div>
        </div>

        {/* Divider */}
        <div className="border-t border-slate-600" />

        {/* Reset button */}
        <button
          onClick={reset}
          className="w-full px-4 py-2 bg-red-600/20 hover:bg-red-600/40 text-red-400 rounded-lg font-medium border border-red-600/50"
        >
          Reset Simulation
        </button>

        {/* Keyboard shortcuts */}
        <div className="text-xs text-slate-500 space-y-1">
          <div className="flex justify-between">
            <span>Set A:</span>
            <kbd className="px-1 bg-slate-700 rounded">1</kbd>
          </div>
          <div className="flex justify-between">
            <span>Set B:</span>
            <kbd className="px-1 bg-slate-700 rounded">2</kbd>
          </div>
          <div className="flex justify-between">
            <span>Clear:</span>
            <kbd className="px-1 bg-slate-700 rounded">C</kbd>
          </div>
          <div className="flex justify-between">
            <span>Reset:</span>
            <kbd className="px-1 bg-slate-700 rounded">R</kbd>
          </div>
        </div>
      </div>
    </div>
  );
}
